'use strict';

const callService = require('../services/callService');
const notificationService = require('../services/notificationService');
const mediaService = require('../services/mediaService');
const { emitToUser } = require('../sockets/emitter');
const catchAsync = require('../utils/catchAsync');
const logger = require('../config/logger');

const createCall = catchAsync(async (req, res) => {
  const { receiverIds, callType, conversationId } = req.body;
  const { call, receiver } = await callService.createCall({
    callerId: req.user._id,
    receiverIds,
    callType,
    conversationId,
  });

  const payload = {
    call: call.toPublic(),
    caller: {
      id: req.user._id.toString(),
      displayName: req.user.displayName,
      username: req.user.username,
      photoURL: req.user.photoURL,
    },
  };
  emitToUser(receiver._id, 'call:incoming', payload);
  emitToUser(req.user._id, 'call:ringing', { call: call.toPublic() });
  emitToUser(receiver._id, 'call:ringing', { call: call.toPublic() });

  notificationService
    .sendToUser(receiver._id, {
      title: req.user.displayName,
      body: callType === 'video' ? 'Incoming video call' : 'Incoming voice call',
      data: {
        type: 'incoming_call',
        callId: call._id.toString(),
        callerId: req.user._id.toString(),
        callType,
        conversationId: conversationId || '',
      },
      type: 'incoming_call',
      highPriority: true,
    })
    .catch((err) => logger.warn({ err: err.message }, '[call] incoming push failed'));

  res.status(201).json({ success: true, data: payload });
});

const acceptCall = catchAsync(async (req, res) => {
  const call = await callService.acceptCall({ callId: req.params.id, userId: req.user._id });
  const payload = {
    call: call.toPublic(),
    acceptedBy: {
      id: req.user._id.toString(),
      displayName: req.user.displayName,
      photoURL: req.user.photoURL,
    },
  };
  emitToUser(call.callerId, 'call:accept', payload);
  emitToUser(req.user._id, 'call:accept', payload);
  res.json({ success: true, data: payload });
});

const rejectCall = catchAsync(async (req, res) => {
  const call = await callService.endCall({
    callId: req.params.id,
    userId: req.user._id,
    status: 'rejected',
  });
  emitToUser(call.callerId, 'call:reject', {
    call: call.toPublic(),
    rejectedBy: req.user._id.toString(),
  });
  res.json({ success: true, data: { call: call.toPublic() } });
});

const endCall = catchAsync(async (req, res) => {
  const existing = await callService.getCallForUser(req.params.id, req.user._id);
  const call = await callService.endCall({
    callId: req.params.id,
    userId: req.user._id,
    status: req.body.status,
  });
  const others = [String(call.callerId), ...call.receiverIds.map(String)].filter(
    (id) => id !== String(req.user._id)
  );
  others.forEach((id) => {
    emitToUser(id, 'call:end', {
      call: call.toPublic(),
      endedBy: req.user._id.toString(),
    });
  });
  // Missed call notification when a ringing call never got answered.
  if (!existing.answeredAt && call.status !== 'rejected') {
    const receivers = call.receiverIds.map(String);
    receivers
      .filter((id) => id !== String(req.user._id))
      .forEach((id) => {
        notificationService
          .sendToUser(id, {
            title: 'Missed call',
            body: `You missed a ${call.callType} call from ${req.user.displayName}`,
            data: { type: 'missed_call', callId: call._id.toString() },
            type: 'missed_call',
          })
          .catch(() => {});
      });
  }
  res.json({ success: true, data: { call: call.toPublic() } });
});

const busyCall = catchAsync(async (req, res) => {
  const call = await callService.getCallForUser(req.params.id, req.user._id);
  const ended = await callService.endCall({
    callId: req.params.id,
    userId: req.user._id,
    status: 'busy',
  });
  const others = [String(call.callerId), ...call.receiverIds.map(String)].filter(
    (id) => id !== String(req.user._id)
  );
  others.forEach((id) => emitToUser(id, 'call:busy', { call: ended.toPublic() }));
  res.json({ success: true, data: { call: ended.toPublic() } });
});

const history = catchAsync(async (req, res) => {
  const calls = await callService.callHistory({
    userId: req.user._id,
    limit: req.query.limit,
    cursor: req.query.cursor,
  });
  const users = new Map();
  calls.forEach((c) => {
    [c.callerId, ...c.receiverIds].forEach((u) => {
      if (u && u._id) users.set(u._id.toString(), u);
    });
  });
  res.json({
    success: true,
    data: {
      calls: calls.map((c) => ({
        id: c._id.toString(),
        callerId: c.callerId._id ? c.callerId._id.toString() : String(c.callerId),
        caller: c.callerId._id
          ? {
              id: c.callerId._id.toString(),
              displayName: c.callerId.displayName,
              username: c.callerId.username,
              photoURL: c.callerId.photoURL,
            }
          : null,
        receiverIds: c.receiverIds.map((r) => (r._id ? r._id.toString() : String(r))),
        receivers: c.receiverIds
          .filter((r) => r._id)
          .map((r) => ({
            id: r._id.toString(),
            displayName: r.displayName,
            username: r.username,
            photoURL: r.photoURL,
          })),
        callType: c.callType,
        status: c.status,
        startedAt: c.startedAt,
        answeredAt: c.answeredAt,
        endedAt: c.endedAt,
        duration: c.duration,
        createdAt: c.createdAt,
        direction:
          String(c.callerId._id || c.callerId) === String(req.user._id) ? 'outgoing' : 'incoming',
      })),
    },
  });
});

const getCall = catchAsync(async (req, res) => {
  const call = await callService.getCallForUser(req.params.id, req.user._id);
  res.json({ success: true, data: { call: call.toPublic() } });
});

/** ICE servers (STUN + TURN). Credentials stay server-side. */
const iceServers = catchAsync(async (_req, res) => {
  res.json({ success: true, data: { iceServers: mediaService.getIceServers() } });
});

module.exports = {
  createCall,
  acceptCall,
  rejectCall,
  endCall,
  busyCall,
  history,
  getCall,
  iceServers,
};
