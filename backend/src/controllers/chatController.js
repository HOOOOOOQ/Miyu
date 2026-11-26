'use strict';

const { Conversation } = require('../models');
const chatService = require('../services/chatService');
const { conversationToPublic } = require('../utils/serializers');
const catchAsync = require('../utils/catchAsync');
const ApiError = require('../utils/ApiError');

const listChats = catchAsync(async (req, res) => {
  const includeArchived = String(req.query.includeArchived || 'false') === 'true';
  const type = req.query.type;
  let conversations = await chatService.listConversationsForUser(req.user._id, { includeArchived });
  if (type === 'direct' || type === 'group') {
    conversations = conversations.filter((c) => c.conversationType === type);
  }
  const data = conversations.map((c) =>
    conversationToPublic(c, req.user._id, {
      lastMessage: c.lastMessage,
      group: c.group,
      participants: c.participants,
    })
  );
  res.json({ success: true, data: { chats: data } });
});

const createChat = catchAsync(async (req, res) => {
  const { participantId } = req.body;
  const conversation = await chatService.getOrCreateDirectConversation(req.user._id, participantId);
  const populated = await Conversation.findById(conversation._id)
    .populate({ path: 'lastMessage' })
    .populate({ path: 'group' })
    .populate({ path: 'participants', select: 'displayName username photoURL isOnline lastSeen showOnlineStatus showLastSeen' })
    .lean();
  res.status(201).json({
    success: true,
    data: {
      chat: conversationToPublic(populated, req.user._id, {
        lastMessage: populated.lastMessage,
        group: populated.group,
        participants: populated.participants,
      }),
    },
  });
});

const getChat = catchAsync(async (req, res) => {
  const conversation = await chatService.assertParticipant(req.params.id, req.user._id);
  const populated = await Conversation.findById(conversation._id)
    .populate({ path: 'lastMessage' })
    .populate({ path: 'group' })
    .populate({ path: 'participants', select: 'displayName username photoURL isOnline lastSeen showOnlineStatus showLastSeen bio' })
    .lean();
  res.json({
    success: true,
    data: {
      chat: conversationToPublic(populated, req.user._id, {
        lastMessage: populated.lastMessage,
        group: populated.group,
        participants: populated.participants,
      }),
    },
  });
});

const deleteChat = catchAsync(async (req, res) => {
  const conversation = await chatService.assertParticipant(req.params.id, req.user._id);
  if (conversation.conversationType === 'group') {
    throw ApiError.badRequest('Leave the group instead of deleting the conversation', 'GROUP_CHAT');
  }
  await Message.deleteMany({ conversationId: conversation._id });
  await Conversation.deleteOne({ _id: conversation._id });
  res.json({ success: true, data: { deleted: true } });
});

const archiveChat = catchAsync(async (req, res) => {
  await chatService.assertParticipant(req.params.id, req.user._id);
  const archive = req.body.archive !== false;
  const update = archive
    ? { $addToSet: { archivedBy: req.user._id } }
    : { $pull: { archivedBy: req.user._id } };
  await Conversation.updateOne({ _id: req.params.id }, update);
  res.json({ success: true, data: { archived: archive } });
});

const pinChat = catchAsync(async (req, res) => {
  await chatService.assertParticipant(req.params.id, req.user._id);
  const pin = req.body.pin !== false;
  const update = pin
    ? { $addToSet: { pinnedBy: req.user._id } }
    : { $pull: { pinnedBy: req.user._id } };
  await Conversation.updateOne({ _id: req.params.id }, update);
  res.json({ success: true, data: { pinned: pin } });
});

const muteChat = catchAsync(async (req, res) => {
  await chatService.assertParticipant(req.params.id, req.user._id);
  const mute = req.body.mute !== false;
  const update = mute
    ? { $addToSet: { mutedBy: req.user._id } }
    : { $pull: { mutedBy: req.user._id } };
  await Conversation.updateOne({ _id: req.params.id }, update);
  res.json({ success: true, data: { muted: mute } });
});

const listMessages = catchAsync(async (req, res) => {
  const result = await chatServiceMessageService.listMessages({
    userId: req.user._id,
    conversationId: req.params.id,
    query: req.query,
  });
  res.json({ success: true, data: result });
});

const sendMessage = catchAsync(async (req, res) => {
  const { conversationId, ...rest } = req.body;
  const { message, recipientIds, duplicate } = await require('../services/messageService').createMessage({
    senderId: req.user._id,
    conversationId,
    payload: rest,
  });
  const { emitToUsers, emitToConversation } = require('../sockets/emitter');
  if (!duplicate) {
    emitToUsers(recipientIds, 'message:new', { message });
    emitToConversation(String(conversationId), 'message:new', { message });
  }
  res.status(duplicate ? 200 : 201).json({ success: true, data: { message, duplicate } });
});

const markRead = catchAsync(async (req, res) => {
  const messageService = require('../services/messageService');
  const result = await messageService.markRead({
    conversationId: req.params.id,
    userId: req.user._id,
  });
  const { emitToConversation } = require('../sockets/emitter');
  emitToConversation(String(req.params.id), 'message:read', {
    conversationId: String(req.params.id),
    userId: String(req.user._id),
    messageIds: result.messageIds,
    readAt: result.readAt,
  });
  res.json({ success: true, data: result });
});

const markDelivered = catchAsync(async (req, res) => {
  const messageService = require('../services/messageService');
  const result = await messageService.markDelivered({
    conversationId: req.params.id,
    userId: req.user._id,
  });
  const { emitToConversation } = require('../sockets/emitter');
  emitToConversation(String(req.params.id), 'message:delivered', {
    conversationId: String(req.params.id),
    userId: String(req.user._id),
    messageIds: result.messageIds,
    deliveredAt: result.deliveredAt,
  });
  res.json({ success: true, data: result });
});

// Small indirection keeps the require at top-of-file list tidy for lint rules.
const chatServiceMessageService = require('../services/messageService');

module.exports = {
  listChats,
  createChat,
  getChat,
  deleteChat,
  archiveChat,
  pinChat,
  muteChat,
  listMessages,
  sendMessage,
  markRead,
  markDelivered,
};
