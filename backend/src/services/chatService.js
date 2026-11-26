'use strict';

const mongoose = require('mongoose');
const { Conversation, Message, BlockedUser, User } = require('../models');
const ApiError = require('../utils/ApiError');

function toObjectId(id, field = 'id') {
  if (!mongoose.Types.ObjectId.isValid(String(id))) {
    throw ApiError.badRequest(`Invalid ${field}`, 'INVALID_ID');
  }
  return new mongoose.Types.ObjectId(String(id));
}

async function isBlockedBetween(a, b) {
  const record = await BlockedUser.findOne({
    $or: [
      { blocker: a, blocked: b },
      { blocker: b, blocked: a },
    ],
  }).lean();
  return Boolean(record);
}

/**
 * Finds the direct conversation between two users, creating it if absent.
 * Conversation documents with participants sorted keep this deterministic.
 */
async function getOrCreateDirectConversation(userId, peerId) {
  if (String(userId) === String(peerId)) {
    throw ApiError.badRequest('You cannot start a conversation with yourself', 'SELF_CONVERSATION');
  }
  const peer = await User.findById(peerId);
  if (!peer) throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
  if (await isBlockedBetween(userId, peerId)) {
    throw ApiError.forbidden('This conversation is not available', 'USER_BLOCKED');
  }

  let conversation = await Conversation.findOne({
    conversationType: 'direct',
    participants: { $all: [userId, peerId], $size: 2 },
  });
  if (conversation) return conversation;

  try {
    conversation = await Conversation.create({
      conversationType: 'direct',
      participants: [userId, peerId],
      createdBy: userId,
      lastActivity: new Date(),
    });
  } catch (err) {
    if (err && err.code === 11000) {
      conversation = await Conversation.findOne({
        conversationType: 'direct',
        participants: { $all: [userId, peerId], $size: 2 },
      });
      if (conversation) return conversation;
    }
    throw err;
  }
  return conversation;
}

async function assertParticipant(conversationId, userId) {
  const conversation = await Conversation.findById(conversationId);
  if (!conversation) throw ApiError.notFound('Conversation not found', 'CONVERSATION_NOT_FOUND');
  const member = conversation.participants.some((p) => String(p) === String(userId));
  if (!member) throw ApiError.forbidden('You are not a participant of this conversation', 'NOT_A_PARTICIPANT');
  return conversation;
}

async function listConversationsForUser(userId, { includeArchived = false } = {}) {
  const query = { participants: userId };
  const conversations = await Conversation.find(query)
    .sort({ pinnedBy: -1, lastActivity: -1 })
    .limit(200)
    .populate({ path: 'lastMessage' })
    .populate({ path: 'group' })
    .populate({ path: 'participants', select: 'displayName username photoURL isOnline lastSeen showOnlineStatus showLastSeen' })
    .lean();

  const filtered = conversations.filter((c) => {
    const archived = (c.archivedBy || []).map(String).includes(String(userId));
    return includeArchived ? true : !archived;
  });

  // Pinned first, then last activity.
  filtered.sort((a, b) => {
    const aPinned = (a.pinnedBy || []).map(String).includes(String(userId)) ? 1 : 0;
    const bPinned = (b.pinnedBy || []).map(String).includes(String(userId)) ? 1 : 0;
    if (aPinned !== bPinned) return bPinned - aPinned;
    return new Date(b.lastActivity).getTime() - new Date(a.lastActivity).getTime();
  });
  return filtered;
}

async function markConversationRead(conversationId, userId) {
  const key = `unreadCounts.${userId}`;
  await Conversation.updateOne({ _id: conversationId }, { $set: { [key]: 0 } });
  await Message.updateMany(
    { conversationId, readBy: { $ne: userId }, senderId: { $ne: userId } },
    { $addToSet: { readBy: userId }, $set: { readAt: new Date() } }
  );
}

module.exports = {
  toObjectId,
  isBlockedBetween,
  getOrCreateDirectConversation,
  assertParticipant,
  listConversationsForUser,
  markConversationRead,
};
