'use strict';

const { Server } = require('socket.io');
const { verifyAccessToken } = require('../utils/tokens');
const { isConnected } = require('../config/db');
const { User, Conversation } = require('../models');
const messageService = require('../services/messageService');
const callService = require('../services/callService');
const chatService = require('../services/chatService');
const { setIo, userRoom, conversationRoom } = require('./emitter');
const logger = require('../config/logger');
const { env } = require('../config/env');

/** socketId → Set of conversation ids joined (used for presence/typing fan-out) */
const onlineSockets = new Map(); // userId -> Set<socketId>
const socketConversations = new Map(); // socketId -> Set<conversationId>

function isOnline(userId) {
  const set = onlineSockets.get(String(userId));
  return Boolean(set && set.size > 0);
}

function conversationWatchers(conversationId, exceptSocketId = null) {
  const ids = [];
  socketConversations.forEach((convs, socketId) => {
    if (socketId === exceptSocketId) return;
    if (convs.has(String(conversationId))) ids.push(socketId);
  });
  return ids;
}

function initSocket(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: env.corsOrigins.includes('*') ? true : env.corsOrigins,
      methods: ['GET', 'POST'],
      credentials: true,
    },
    pingTimeout: 30000,
    pingInterval: 25000,
    maxHttpBufferSize: 1e6,
  });

  setIo(io);

  // Authenticate every socket connection with the same JWT used by REST.
  io.use(async (socket, next) => {
    try {
      const token =
        (socket.handshake.auth && socket.handshake.auth.token) ||
        (socket.handshake.query && socket.handshake.query.token) ||
        (socket.handshake.headers.authorization || '').replace(/^Bearer\s+/i, '');
      if (!token) return next(new Error('unauthorized'));
      let payload;
      try {
        payload = verifyAccessToken(token);
      } catch (_e) {
        return next(new Error('unauthorized'));
      }
      const user = await User.findById(payload.sub).select('_id displayName username photoURL');
      if (!user) return next(new Error('unauthorized'));
      socket.user = {
        id: user._id.toString(),
        displayName: user.displayName,
        username: user.username,
        photoURL: user.photoURL,
      };
      return next();
    } catch (err) {
      logger.warn({ err: err.message }, '[socket] auth failed');
      return next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.user.id;
    socket.join(userRoom(userId));
    if (!onlineSockets.has(userId)) onlineSockets.set(userId, new Set());
    const firstConnection = onlineSockets.get(userId).size === 0;
    onlineSockets.get(userId).add(socket.id);
    socketConversations.set(socket.id, new Set());

    const broadcastPresence = async (isOnlineNow) => {
      const payload = {
        userId,
        isOnline: isOnlineNow,
        lastSeen: new Date().toISOString(),
        displayName: socket.user.displayName,
      };
      // Notify everyone sharing a conversation with this user.
      const conversations = await Conversation.find({ participants: userId }).select('participants').lean();
      const peerIds = new Set();
      conversations.forEach((c) => c.participants.forEach((p) => peerIds.add(String(p))));
      peerIds.delete(userId);
      peerIds.forEach((peer) => io.to(userRoom(peer)).emit('user:status', payload));
      io.emit('user:status', payload);
    };

    if (firstConnection) {
      User.updateOne({ _id: userId }, { $set: { isOnline: true, lastSeen: new Date() } })
        .then(() => broadcastPresence(true))
        .catch(() => {});
      socket.broadcast.emit('user:online', { userId, isOnline: true });
    }

    // ---- presence -------------------------------------------------------
    socket.on('user:online', () => {
      User.updateOne({ _id: userId }, { $set: { isOnline: true, lastSeen: new Date() } })
        .then(() => broadcastPresence(true))
        .catch(() => {});
    });
    socket.on('user:offline', () => {
      User.updateOne({ _id: userId }, { $set: { isOnline: false, lastSeen: new Date() } })
        .then(() => broadcastPresence(false))
        .catch(() => {});
    });

    // ---- rooms ----------------------------------------------------------
    socket.on('chat:join', (payload, ack) => {
      const conversationId = typeof payload === 'string' ? payload : payload && payload.conversationId;
      if (!conversationId) return ack && ack({ ok: false, error: 'conversationId required' });
      return chatService
        .assertParticipant(conversationId, userId)
        .then(() => {
          socket.join(conversationRoom(conversationId));
          socketConversations.get(socket.id).add(String(conversationId));
          if (ack) ack({ ok: true });
          return messageService.markDelivered({ conversationId, userId }).then((result) => {
            if (result.messageIds.length) {
              io.to(conversationRoom(conversationId)).emit('message:delivered', {
                conversationId: String(conversationId),
                userId,
                messageIds: result.messageIds,
                deliveredAt: result.deliveredAt,
              });
            }
          });
        })
        .catch((err) => ack && ack({ ok: false, error: err.message }));
    });

    socket.on('chat:leave', (payload) => {
      const conversationId = typeof payload === 'string' ? payload : payload && payload.conversationId;
      if (!conversationId) return;
      socket.leave(conversationRoom(conversationId));
      const set = socketConversations.get(socket.id);
      if (set) set.delete(String(conversationId));
    });

    // ---- messages -------------------------------------------------------
    socket.on('message:send', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        if (!payload || !payload.conversationId) {
          return respond({ ok: false, error: 'conversationId required' });
        }
        const { conversationId, ...rest } = payload;
        const { message, recipientIds, duplicate } = await messageService.createMessage({
          senderId: userId,
          conversationId,
          payload: rest,
        });
        if (!duplicate) {
          const eventPayload = { message };
          io.to(conversationRoom(conversationId)).emit('message:new', eventPayload);
          recipientIds.forEach((rid) => io.to(userRoom(rid)).emit('message:new', eventPayload));
        }
        return respond({ ok: true, message, duplicate });
      } catch (err) {
        logger.warn({ err: err.message, userId }, '[socket] message:send failed');
        return respond({ ok: false, error: err.message, code: err.code });
      }
    });

    socket.on('message:read', async (payload, ack) => {
      const conversationId = payload && (payload.conversationId || payload);
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        if (!conversationId) return respond({ ok: false, error: 'conversationId required' });
        const result = await messageService.markRead({ conversationId, userId });
        io.to(conversationRoom(conversationId)).emit('message:read', {
          conversationId: String(conversationId),
          userId,
          messageIds: result.messageIds,
          readAt: result.readAt,
        });
        return respond({ ok: true, messageIds: result.messageIds });
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    socket.on('message:delivered', async (payload, ack) => {
      const conversationId = payload && payload.conversationId;
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const result = await messageService.markDelivered({ conversationId, userId });
        if (result.messageIds.length) {
          io.to(conversationRoom(conversationId)).emit('message:delivered', {
            conversationId: String(conversationId),
            userId,
            messageIds: result.messageIds,
            deliveredAt: result.deliveredAt,
          });
        }
        return respond({ ok: true });
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    socket.on('message:edit', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const message = await messageService.editMessage({
          messageId: payload.messageId,
          userId,
          content: payload.content,
        });
        const eventPayload = {
          messageId: String(message._id),
          conversationId: String(message.conversationId),
          content: message.content,
          editedAt: message.editedAt,
        };
        io.to(conversationRoom(message.conversationId)).emit('message:edit', eventPayload);
        return respond({ ok: true, ...eventPayload });
      } catch (err) {
        return respond({ ok: false, error: err.message, code: err.code });
      }
    });

    socket.on('message:delete', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const { deleted, mode, message } = await messageService.deleteMessage({
          messageId: payload.messageId,
          userId,
          mode: payload.mode || 'everyone',
        });
        const eventPayload = {
          messageId: String(message._id),
          conversationId: String(message.conversationId),
          mode,
          userId: mode === 'me' ? userId : null,
        };
        io.to(conversationRoom(message.conversationId)).emit('message:delete', eventPayload);
        return respond({ ok: deleted, ...eventPayload });
      } catch (err) {
        return respond({ ok: false, error: err.message, code: err.code });
      }
    });

    socket.on('message:reaction', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const message = await messageService.reactToMessage({
          messageId: payload.messageId,
          userId,
          emoji: payload.emoji === null ? null : String(payload.emoji || ''),
        });
        const eventPayload = {
          messageId: String(message._id),
          conversationId: String(message.conversationId),
          reactions: message.reactions.map((r) => ({ user: String(r.user), emoji: r.emoji })),
          userId,
        };
        io.to(conversationRoom(message.conversationId)).emit('message:reaction', eventPayload);
        return respond({ ok: true, ...eventPayload });
      } catch (err) {
        return respond({ ok: false, error: err.message, code: err.code });
      }
    });

    // ---- typing ---------------------------------------------------------
    const relayTyping = (event) => (payload) => {
      const conversationId = payload && payload.conversationId;
      if (!conversationId) return;
      const targets = conversationWatchers(conversationId, socket.id);
      const data = {
        conversationId: String(conversationId),
        userId,
        displayName: socket.user.displayName,
      };
      targets.forEach((socketId) => io.to(socketId).emit(event, data));
    };
    socket.on('typing:start', relayTyping('typing:start'));
    socket.on('typing:stop', relayTyping('typing:stop'));

    // ---- WebRTC signaling -----------------------------------------------
    const forwardCallSignal = (targetUserId, event, payload, ack) => {
      if (!targetUserId) return ack && ack({ ok: false, error: 'targetUserId required' });
      io.to(userRoom(targetUserId)).emit(event, { ...payload, from: userId });
      return ack && ack({ ok: true });
    };

    socket.on('call:offer', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const call = await callService.getCallForUser(payload.callId, userId);
        const target = String(call.callerId) === userId
          ? call.receiverIds.map(String)[0]
          : String(call.callerId);
        return forwardCallSignal(target, 'call:offer', { callId: payload.callId, sdp: payload.sdp }, respond);
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    socket.on('call:answer', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const call = await callService.getCallForUser(payload.callId, userId);
        const target = String(call.callerId) === userId
          ? call.receiverIds.map(String)[0]
          : String(call.callerId);
        return forwardCallSignal(target, 'call:answer', { callId: payload.callId, sdp: payload.sdp }, respond);
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    socket.on('call:ice-candidate', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const call = await callService.getCallForUser(payload.callId, userId);
        const target = String(call.callerId) === userId
          ? call.receiverIds.map(String)[0]
          : String(call.callerId);
        return forwardCallSignal(
          target,
          'call:ice-candidate',
          { callId: payload.callId, candidate: payload.candidate },
          respond
        );
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    // Call setup push (accept/reject/end/busy) also arrives over HTTP REST;
    // sockets provide lower-latency delivery to online peers.
    socket.on('call:accept', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const call = await callService.acceptCall({ callId: payload.callId, userId });
        const data = { call: call.toPublic(), acceptedBy: { id: userId, displayName: socket.user.displayName } };
        io.to(userRoom(String(call.callerId))).emit('call:accept', data);
        io.to(userRoom(userId)).emit('call:accept', data);
        return respond({ ok: true, ...data });
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    socket.on('call:reject', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const call = await callService.endCall({ callId: payload.callId, userId, status: 'rejected' });
        const data = { call: call.toPublic(), rejectedBy: userId };
        io.to(userRoom(String(call.callerId))).emit('call:reject', data);
        return respond({ ok: true, ...data });
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    socket.on('call:end', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const call = await callService.endCall({ callId: payload.callId, userId, status: payload.status });
        const targets = [String(call.callerId), ...call.receiverIds.map(String)].filter((id) => id !== userId);
        const data = { call: call.toPublic(), endedBy: userId };
        targets.forEach((t) => io.to(userRoom(t)).emit('call:end', data));
        return respond({ ok: true, ...data });
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    socket.on('call:busy', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};
      try {
        const call = await callService.endCall({ callId: payload.callId, userId, status: 'busy' });
        io.to(userRoom(String(call.callerId))).emit('call:busy', { call: call.toPublic() });
        return respond({ ok: true });
      } catch (err) {
        return respond({ ok: false, error: err.message });
      }
    });

    // ---- group room helpers --------------------------------------------
    socket.on('group:join', (payload, ack) => {
      const conversationId = typeof payload === 'string' ? payload : payload && payload.conversationId;
      if (conversationId) {
        socket.join(conversationRoom(conversationId));
        socketConversations.get(socket.id).add(String(conversationId));
      }
      if (ack) ack({ ok: true });
    });

    // ---- disconnect -----------------------------------------------------
    socket.on('disconnect', async () => {
      const set = onlineSockets.get(userId);
      socketConversations.delete(socket.id);
      if (set) {
        set.delete(socket.id);
        if (set.size === 0) {
          onlineSockets.delete(userId);
          const lastSeen = new Date();
          await User.updateOne({ _id: userId }, { $set: { isOnline: false, lastSeen } }).catch(() => {});
          const payload = { userId, isOnline: false, lastSeen: lastSeen.toISOString() };
          const conversations = await Conversation.find({ participants: userId })
            .select('participants')
            .lean()
            .catch(() => []);
          const peerIds = new Set();
          conversations.forEach((c) => c.participants.forEach((p) => peerIds.add(String(p))));
          peerIds.delete(userId);
          peerIds.forEach((peer) => io.to(userRoom(peer)).emit('user:status', payload));
          io.emit('user:status', payload);
          socket.broadcast.emit('user:offline', payload);
        }
      }
    });
  });

  // Sweep stale ringing calls every 20s so history does not fill with zombie calls.
  // Skipped while the database is disconnected: mongoose buffers the query for
  // 10s and then throws, which used to fill the panel console with the same
  // "buffering timed out" error every 20 seconds during a DB outage.
  const sweeper = setInterval(() => {
    if (!isConnected()) return;
    callService
      .expireStaleCalls()
      .catch((err) => logger.warn({ err: err.message }, '[call] sweep failed'));
  }, 20_000);
  if (sweeper.unref) sweeper.unref();

  return io;
}

module.exports = { initSocket, isOnline, onlineSockets };
