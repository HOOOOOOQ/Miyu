'use strict';

const { Conversation, Message, Group } = require('../models');
const { assertParticipant, isBlockedBetween } = require('./chatService');
const { messageToPublic } = require('../utils/serializers');
const { parsePagination, encodeCursor, decodeCursor } = require('../utils/pagination');
const ApiError = require('../utils/ApiError');

const MESSAGE_TYPES = ['text', 'image', 'video', 'file', 'audio'];
const MEDIA_TYPES = new Set(['image', 'video', 'file', 'audio']);

/**
 * Persists a message, updates conversation metadata, and returns the API-shaped
 * message plus the ids that need delivery/notification fan-out.
 */
async function createMessage({ senderId, conversationId, payload }) {
  const conversation = await assertParticipant(conversationId, senderId);

  const {
    content = '',
    messageType = 'text',
    mediaUrl = null,
    mediaMeta = null,
    replyTo = null,
    forwardedFrom = null,
    clientMessageId = null,
  } = payload;

  if (!MESSAGE_TYPES.includes(messageType)) {
    throw ApiError.badRequest(`Unsupported messageType: ${messageType}`, 'INVALID_MESSAGE_TYPE');
  }
  if (messageType === 'text' && (!content || !String(content).trim())) {
    throw ApiError.badRequest('Message content is required for text messages', 'EMPTY_MESSAGE');
  }
  if (MEDIA_TYPES.has(messageType) && !mediaUrl) {
    throw ApiError.badRequest('mediaUrl is required for media messages', 'MISSING_MEDIA');
  }

  const isGroup = conversation.conversationType === 'group';
  if (isGroup && conversation.group) {
    const group = await Group.findById(conversation.group);
    if (group && group.memberPermissions && group.memberPermissions.sendMessages === false) {
      const isAdmin = group.admins.some((a) => String(a) === String(senderId));
      if (!isAdmin) {
        throw ApiError.forbidden('Only admins can send messages in this group', 'GROUP_MESSAGES_RESTRICTED');
      }
    }
  } else {
    const peerId = conversation.participants.map(String).find((p) => p !== String(senderId));
    if (peerId && (await isBlockedBetween(senderId, peerId))) {
      throw ApiError.forbidden('You cannot message this user', 'USER_BLOCKED');
    }
  }

  if (replyTo) {
    const parent = await Message.findById(replyTo).select('_id conversationId');
    if (!parent || String(parent.conversationId) !== String(conversation._id)) {
      throw ApiError.badRequest('replyTo must reference a message in this conversation', 'INVALID_REPLY');
    }
  }

  const recipientIds = conversation.participants.map(String).filter((p) => p !== String(senderId));

  // Duplicate protection: retried client sends return the original document.
  if (clientMessageId) {
    const existing = await Message.findOne({ senderId, clientMessageId });
    if (existing) {
      const enriched = await Message.findById(existing._id).populate({
        path: 'replyTo',
        select: 'content messageType senderId mediaUrl createdAt',
      });
      return {
        message: messageToPublic(enriched),
        conversation,
        recipientIds,
        duplicate: true,
      };
    }
  }

  let message;
  try {
    message = await Message.create({
      conversationId: conversation._id,
      senderId,
      clientMessageId: clientMessageId || null,
      messageType,
      content: messageType === 'text' ? String(content).trim() : String(content || ''),
      mediaUrl,
      mediaMeta: mediaMeta || null,
      replyTo: replyTo || null,
      forwardedFrom: forwardedFrom || null,
      deliveredTo: [senderId],
      readBy: [senderId],
    });
  } catch (err) {
    if (err && err.code === 11000 && clientMessageId) {
      const existing = await Message.findOne({ senderId, clientMessageId });
      if (existing) {
        return { message: messageToPublic(existing), conversation, recipientIds, duplicate: true };
      }
    }
    throw err;
  }

  const unreadInc = {};
  recipientIds.forEach((rid) => {
    unreadInc[`unreadCounts.${rid}`] = 1;
  });
  await Conversation.updateOne(
    { _id: conversation._id },
    {
      $set: { lastMessage: message._id, lastActivity: message.createdAt },
      ...(Object.keys(unreadInc).length ? { $inc: unreadInc } : {}),
      $pull: { archivedBy: { $in: conversation.participants } },
    }
  );

  const enriched = await Message.findById(message._id).populate({
    path: 'replyTo',
    select: 'content messageType senderId mediaUrl createdAt',
  });
  return {
    message: messageToPublic(enriched),
    conversation,
    recipientIds,
    duplicate: false,
  };
}

async function listMessages({ userId, conversationId, query }) {
  await assertParticipant(conversationId, userId);
  const { limit, cursor } = parsePagination(query, { defaultLimit: 30, maxLimit: 100 });
  const filter = { conversationId, deletedFor: { $ne: userId } };

  const decoded = decodeCursor(cursor);
  if (decoded) {
    filter.$or = [
      { createdAt: { $lt: decoded.createdAt } },
      { createdAt: decoded.createdAt, _id: { $lt: decoded.id } },
    ];
  }

  const docs = await Message.find(filter)
    .sort({ createdAt: -1, _id: -1 })
    .limit(limit + 1)
    .populate({ path: 'replyTo', select: 'content messageType senderId mediaUrl createdAt' });

  const hasMore = docs.length > limit;
  const page = hasMore ? docs.slice(0, limit) : docs;
  const nextCursor = hasMore ? encodeCursor(page[page.length - 1]) : null;

  return {
    messages: page.map((m) => messageToPublic(m)).reverse(),
    nextCursor,
    hasMore,
  };
}

async function getMessageForUser(messageId, userId) {
  const message = await Message.findById(messageId);
  if (!message) throw ApiError.notFound('Message not found', 'MESSAGE_NOT_FOUND');
  await assertParticipant(message.conversationId, userId);
  return message;
}

async function editMessage({ messageId, userId, content }) {
  const message = await getMessageForUser(messageId, userId);
  if (String(message.senderId) !== String(userId)) {
    throw ApiError.forbidden('You can only edit your own messages', 'NOT_SENDER');
  }
  if (message.deletedAt) throw ApiError.badRequest('Deleted messages cannot be edited', 'MESSAGE_DELETED');
  if (message.messageType !== 'text') {
    throw ApiError.badRequest('Only text messages can be edited', 'NOT_EDITABLE');
  }
  if (!content || !String(content).trim()) {
    throw ApiError.badRequest('Message content cannot be empty', 'EMPTY_MESSAGE');
  }
  message.content = String(content).trim();
  message.editedAt = new Date();
  await message.save();
  return message;
}

/**
 * mode "me" hides the message for the caller; mode "everyone" soft-deletes it
 * for all participants and is restricted to the sender.
 */
async function deleteMessage({ messageId, userId, mode = 'everyone' }) {
  const message = await getMessageForUser(messageId, userId);
  if (mode === 'me') {
    await Message.updateOne({ _id: message._id }, { $addToSet: { deletedFor: userId } });
    return { deleted: true, mode: 'me', message };
  }
  if (String(message.senderId) !== String(userId)) {
    throw ApiError.forbidden('You can only delete your own messages for everyone', 'NOT_SENDER');
  }
  message.deletedAt = new Date();
  message.content = '';
  message.mediaUrl = null;
  message.mediaMeta = null;
  message.reactions = [];
  await message.save();
  return { deleted: true, mode: 'everyone', message };
}

async function reactToMessage({ messageId, userId, emoji }) {
  const message = await getMessageForUser(messageId, userId);
  if (message.deletedAt) throw ApiError.badRequest('Cannot react to a deleted message', 'MESSAGE_DELETED');
  const existingIndex = message.reactions.findIndex((r) => String(r.user) === String(userId));
  if (emoji === null || emoji === '') {
    if (existingIndex >= 0) message.reactions.splice(existingIndex, 1);
  } else if (existingIndex >= 0) {
    message.reactions[existingIndex].emoji = emoji;
  } else {
    message.reactions.push({ user: userId, emoji });
  }
  await message.save();
  return message;
}

async function markDelivered({ conversationId, userId }) {
  await assertParticipant(conversationId, userId);
  const messages = await Message.find({
    conversationId,
    senderId: { $ne: userId },
    deliveredTo: { $ne: userId },
  }).select('_id');

  if (messages.length === 0) return { messageIds: [], deliveredAt: null };
  const deliveredAt = new Date();
  await Message.updateMany(
    { _id: { $in: messages.map((m) => m._id) } },
    { $addToSet: { deliveredTo: userId }, $set: { deliveredAt } }
  );
  return { messageIds: messages.map((m) => m._id.toString()), deliveredAt };
}

async function markRead({ conversationId, userId }) {
  await assertParticipant(conversationId, userId);
  const messages = await Message.find({
    conversationId,
    senderId: { $ne: userId },
    readBy: { $ne: userId },
  }).select('_id');

  const readAt = new Date();
  if (messages.length > 0) {
    await Message.updateMany(
      { _id: { $in: messages.map((m) => m._id) } },
      { $addToSet: { readBy: userId, deliveredTo: userId }, $set: { readAt } }
    );
    await Conversation.updateOne(
      { _id: conversationId },
      { $set: { [`unreadCounts.${userId}`]: 0 } }
    );
  }
  return { messageIds: messages.map((m) => m._id.toString()), readAt };
}

async function assertCanForward({ messageId, userId }) {
  const message = await Message.findById(messageId).select(
    'conversationId content messageType messageType mediaUrl mediaMeta isDeleted'
  );
  if (!message) throw ApiError.notFound('Message not found', 'MESSAGE_NOT_FOUND');
  await assertParticipant(message.conversationId, userId);
  if (message.deletedAt) throw ApiError.badRequest('Cannot forward a deleted message', 'MESSAGE_DELETED');
  return message;
}

module.exports = {
  createMessage,
  listMessages,
  editMessage,
  deleteMessage,
  reactToMessage,
  markDelivered,
  markRead,
  assertCanForward,
  MESSAGE_TYPES,
};
