'use strict';

const messageService = require('../services/messageService');
const { Conversation } = require('../models');
const { emitToConversation, emitToUsers } = require('../sockets/emitter');
const catchAsync = require('../utils/catchAsync');
const ApiError = require('../utils/ApiError');
const { plainMessageToPublic } = require('../utils/serializers');

const editMessage = catchAsync(async (req, res) => {
  const message = await messageService.editMessage({
    messageId: req.params.id,
    userId: req.user._id,
    content: req.body.content,
  });
  const payload = plainMessageToPublic(message.toObject());
  emitToConversation(String(message.conversationId), 'message:edit', {
    messageId: String(message._id),
    conversationId: String(message.conversationId),
    content: message.content,
    editedAt: message.editedAt,
    message: payload,
  });
  res.json({ success: true, data: { message: payload } });
});

const deleteMessage = catchAsync(async (req, res) => {
  const { deleted, mode, message } = await messageService.deleteMessage({
    messageId: req.params.id,
    userId: req.user._id,
    mode: req.body.mode || req.query.mode || 'everyone',
  });
  emitToConversation(String(message.conversationId), 'message:delete', {
    messageId: String(message._id),
    conversationId: String(message.conversationId),
    mode,
    userId: mode === 'me' ? String(req.user._id) : null,
    message: mode === 'everyone' ? plainMessageToPublic(message.toObject()) : null,
  });
  res.json({ success: true, data: { deleted, mode } });
});

const react = catchAsync(async (req, res) => {
  const message = await messageService.reactToMessage({
    messageId: req.params.id,
    userId: req.user._id,
    emoji: req.body.emoji === null ? null : String(req.body.emoji || ''),
  });
  const payload = plainMessageToPublic(message.toObject());
  emitToConversation(String(message.conversationId), 'message:reaction', {
    messageId: String(message._id),
    conversationId: String(message.conversationId),
    reactions: payload.reactions,
    userId: String(req.user._id),
  });
  res.json({ success: true, data: { message: payload } });
});

/**
 * Forward a message to one or more conversations. Each target reuses
 * createMessage so persistence, unread counts and duplicate protection apply.
 */
const forwardMessage = catchAsync(async (req, res) => {
  const source = await messageService.assertCanForward({
    messageId: req.params.id,
    userId: req.user._id,
  });
  const { conversationIds } = req.body;
  const created = [];
  for (const targetId of conversationIds) {
    const conversation = await Conversation.findById(targetId).select('participants');
    if (!conversation || !conversation.participants.some((p) => String(p) === String(req.user._id))) {
      continue;
    }
    const result = await messageService.createMessage({
      senderId: req.user._id,
      conversationId: targetId,
      payload: {
        messageType: source.messageType === 'system' ? 'text' : source.messageType,
        content: source.content,
        mediaUrl: source.mediaUrl,
        mediaMeta: source.mediaMeta,
        forwardedFrom: source._id,
      },
    });
    created.push(result.message);
    emitToUsers(result.recipientIds, 'message:new', { message: result.message });
    emitToConversation(String(targetId), 'message:new', { message: result.message });
  }
  if (created.length === 0) {
    throw ApiError.badRequest('No valid target conversations', 'NO_TARGETS');
  }
  res.status(201).json({ success: true, data: { messages: created } });
});

module.exports = { editMessage, deleteMessage, react, forwardMessage };
