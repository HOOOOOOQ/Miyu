'use strict';

const groupService = require('../services/groupService');
const { emitToConversation, emitToUsers } = require('../sockets/emitter');
const catchAsync = require('../utils/catchAsync');

function notifyGroup(group, event, payload) {
  emitToConversation(String(group.conversationId), event, payload);
  emitToUsers(group.members.map(String), event, payload);
}

const createGroup = catchAsync(async (req, res) => {
  const { name, description, avatar, memberIds } = req.body;
  const { group, conversation } = await groupService.createGroup({
    ownerId: req.user._id,
    name,
    description,
    avatar,
    memberIds,
  });
  notifyGroup(group, 'group:created', {
    group: group.toPublic(),
    conversationId: String(conversation._id),
  });
  res.status(201).json({
    success: true,
    data: { group: group.toPublic(), conversationId: conversation._id.toString() },
  });
});

const getGroup = catchAsync(async (req, res) => {
  const group = await groupService.getGroupForUser(req.params.id, req.user._id);
  await group.populate('members', 'displayName username photoURL isOnline lastSeen');
  await group.populate('admins', 'displayName username photoURL');
  res.json({
    success: true,
    data: {
      group: {
        ...group.toPublic(),
        memberProfiles: group.members.map((m) =>
          m.displayName ? { id: m._id.toString(), displayName: m.displayName, username: m.username, photoURL: m.photoURL } : { id: m.toString() }
        ),
      },
    },
  });
});

const updateGroup = catchAsync(async (req, res) => {
  const group = await groupService.updateGroup({
    groupId: req.params.id,
    userId: req.user._id,
    updates: req.body,
  });
  notifyGroup(group, 'group:updated', { group: group.toPublic() });
  res.json({ success: true, data: { group: group.toPublic() } });
});

const addMembers = catchAsync(async (req, res) => {
  const { group, added } = await groupService.addMembers({
    groupId: req.params.id,
    userId: req.user._id,
    memberIds: req.body.memberIds,
  });
  emitToConversation(String(group.conversationId), 'group:members', {
    groupId: group._id.toString(),
    added,
    removed: [],
    group: group.toPublic(),
  });
  emitToUsers(group.members.map(String), 'group:members', {
    groupId: group._id.toString(),
    added,
    removed: [],
    group: group.toPublic(),
  });
  res.json({ success: true, data: { group: group.toPublic(), added } });
});

const removeMember = catchAsync(async (req, res) => {
  const { group, removed } = await groupService.removeMember({
    groupId: req.params.id,
    userId: req.user._id,
    targetId: req.params.userId,
  });
  emitToConversation(String(group.conversationId), 'group:members', {
    groupId: group._id.toString(),
    added: [],
    removed: [removed],
    group: group.toPublic(),
  });
  emitToUsers([...group.members.map(String), removed], 'group:members', {
    groupId: group._id.toString(),
    added: [],
    removed: [removed],
    group: group.toPublic(),
  });
  res.json({ success: true, data: { group: group.toPublic(), removed } });
});

const setAdmin = catchAsync(async (req, res) => {
  const group = await groupService.setAdmin({
    groupId: req.params.id,
    userId: req.user._id,
    targetId: req.body.userId,
    makeAdmin: req.body.makeAdmin,
  });
  notifyGroup(group, 'group:updated', { group: group.toPublic() });
  res.json({ success: true, data: { group: group.toPublic() } });
});

const leaveGroup = catchAsync(async (req, res) => {
  const { group } = await groupService.removeMember({
    groupId: req.params.id,
    userId: req.user._id,
    targetId: req.user._id,
  });
  emitToConversation(String(group.conversationId), 'group:members', {
    groupId: group._id.toString(),
    added: [],
    removed: [String(req.user._id)],
    group: group.toPublic(),
  });
  res.json({ success: true, data: { left: true } });
});

const deleteGroup = catchAsync(async (req, res) => {
  const { conversationId } = await groupService.deleteGroup({
    groupId: req.params.id,
    userId: req.user._id,
  });
  emitToConversation(String(conversationId), 'group:deleted', {
    groupId: req.params.id,
    conversationId: String(conversationId),
  });
  res.json({ success: true, data: { deleted: true } });
});

module.exports = {
  createGroup,
  getGroup,
  updateGroup,
  addMembers,
  removeMember,
  setAdmin,
  leaveGroup,
  deleteGroup,
};
