'use strict';

const { Group, Conversation, Message, User } = require('../models');
const ApiError = require('../utils/ApiError');
const { isBlockedBetween } = require('./chatService');

async function createGroup({ ownerId, name, description = '', memberIds = [], avatar = null }) {
  const uniqueIds = [...new Set([String(ownerId), ...memberIds.map(String)])];
  if (uniqueIds.length < 2) {
    throw ApiError.badRequest('A group needs at least one other member', 'GROUP_NEEDS_MEMBERS');
  }
  const users = await User.find({ _id: { $in: uniqueIds } }).select('_id');
  if (users.length !== uniqueIds.length) {
    throw ApiError.badRequest('One or more members do not exist', 'INVALID_MEMBERS');
  }
  for (const id of uniqueIds) {
    if (String(id) === String(ownerId)) continue;
    if (await isBlockedBetween(ownerId, id)) {
      throw ApiError.forbidden('A selected member has blocked you or is blocked by you', 'USER_BLOCKED');
    }
  }

  const group = await Group.create({
    name: String(name).trim(),
    description,
    avatar,
    members: uniqueIds,
    admins: [ownerId],
    owner: ownerId,
  });

  const conversation = await Conversation.create({
    conversationType: 'group',
    participants: uniqueIds,
    group: group._id,
    createdBy: ownerId,
    lastActivity: new Date(),
    unreadCounts: new Map(uniqueIds.filter((id) => String(id) !== String(ownerId)).map((id) => [String(id), 1])),
  });

  group.conversationId = conversation._id;
  await group.save();

  const systemMessage = await Message.create({
    conversationId: conversation._id,
    senderId: ownerId,
    messageType: 'system',
    content: `created the group "${group.name}"`,
    deliveredTo: uniqueIds,
    readBy: [ownerId],
  });
  conversation.lastMessage = systemMessage._id;
  await conversation.save();

  return { group, conversation, systemMessage };
}

async function getGroupForUser(groupId, userId) {
  const group = await Group.findById(groupId);
  if (!group) throw ApiError.notFound('Group not found', 'GROUP_NOT_FOUND');
  if (!group.members.some((m) => String(m) === String(userId))) {
    throw ApiError.forbidden('You are not a member of this group', 'NOT_GROUP_MEMBER');
  }
  return group;
}

function isAdmin(group, userId) {
  return group.admins.some((a) => String(a) === String(userId));
}

async function updateGroup({ groupId, userId, updates }) {
  const group = await getGroupForUser(groupId, userId);
  const admin = isAdmin(group, userId);
  const canEditInfo =
    admin ||
    (group.memberPermissions && group.memberPermissions.editGroupInfo === true);
  if (!canEditInfo) {
    throw ApiError.forbidden('Only group admins can edit group info', 'NOT_GROUP_ADMIN');
  }
  if (updates.name !== undefined) group.name = String(updates.name).trim();
  if (updates.description !== undefined) group.description = updates.description;
  if (updates.avatar !== undefined) group.avatar = updates.avatar;
  if (updates.memberPermissions !== undefined && admin) {
    group.memberPermissions = {
      ...group.memberPermissions.toObject ? group.memberPermissions.toObject() : group.memberPermissions,
      ...updates.memberPermissions,
    };
  }
  await group.save();
  return group;
}

async function addMembers({ groupId, userId, memberIds }) {
  const group = await getGroupForUser(groupId, userId);
  const admin = isAdmin(group, userId);
  if (!admin && !(group.memberPermissions && group.memberPermissions.addMembers)) {
    throw ApiError.forbidden('You cannot add members to this group', 'NOT_ALLOWED');
  }
  const incoming = [...new Set(memberIds.map(String))].filter(
    (id) => !group.members.some((m) => String(m) === String(id))
  );
  if (incoming.length === 0) return { group, added: [] };
  const users = await User.find({ _id: { $in: incoming } }).select('_id displayName');
  if (users.length !== incoming.length) {
    throw ApiError.badRequest('One or more users do not exist', 'INVALID_MEMBERS');
  }
  group.members.push(...incoming);
  await group.save();

  const conversation = await Conversation.findById(group.conversationId);
  if (conversation) {
    const inc = {};
    incoming.forEach((id) => {
      inc[`unreadCounts.${id}`] = 1;
    });
    await Conversation.updateOne(
      { _id: conversation._id },
      { $addToSet: { participants: { $each: incoming } }, ...(Object.keys(inc).length ? { $inc: inc } : {}) }
    );
    const names = users.map((u) => u.displayName).join(', ');
    await Message.create({
      conversationId: conversation._id,
      senderId: userId,
      messageType: 'system',
      content: `added ${names}`,
      deliveredTo: [...group.members, userId],
      readBy: [userId],
    });
    conversation.lastActivity = new Date();
    await conversation.save();
  }
  return { group, added: incoming };
}

async function removeMember({ groupId, userId, targetId }) {
  const group = await getGroupForUser(groupId, userId);
  const target = String(targetId);
  const selfRemove = target === String(userId);
  if (!selfRemove && !isAdmin(group, userId)) {
    throw ApiError.forbidden('Only group admins can remove members', 'NOT_GROUP_ADMIN');
  }
  if (!group.members.some((m) => String(m) === target)) {
    throw ApiError.notFound('User is not a member of this group', 'NOT_A_MEMBER');
  }
  if (target === String(group.owner)) {
    throw ApiError.badRequest('The group owner cannot be removed; transfer ownership or delete the group', 'OWNER_REMOVAL');
  }
  group.members = group.members.filter((m) => String(m) !== target);
  group.admins = group.admins.filter((a) => String(a) !== target);
  await group.save();

  if (group.conversationId) {
    await Conversation.updateOne(
      { _id: group.conversationId },
      { $pull: { participants: target, pinnedBy: target, archivedBy: target, mutedBy: target } }
    );
    const left = await User.findById(target).select('displayName');
    await Message.create({
      conversationId: group.conversationId,
      senderId: userId,
      messageType: 'system',
      content: selfRemove
        ? `${left ? left.displayName : 'A member'} left the group`
        : `removed ${left ? left.displayName : 'a member'}`,
      deliveredTo: group.members,
      readBy: [userId],
    });
  }
  return { group, removed: target };
}

async function setAdmin({ groupId, userId, targetId, makeAdmin = true }) {
  const group = await getGroupForUser(groupId, userId);
  if (String(group.owner) !== String(userId)) {
    throw ApiError.forbidden('Only the group owner can change admin roles', 'NOT_OWNER');
  }
  const target = String(targetId);
  if (!group.members.some((m) => String(m) === target)) {
    throw ApiError.notFound('User is not a member', 'NOT_A_MEMBER');
  }
  if (makeAdmin) {
    group.admins = [...new Set([...group.admins.map(String), target])];
  } else if (target !== String(group.owner)) {
    group.admins = group.admins.filter((a) => String(a) !== target);
  }
  await group.save();
  return group;
}

async function deleteGroup({ groupId, userId }) {
  const group = await getGroupForUser(groupId, userId);
  if (String(group.owner) !== String(userId)) {
    throw ApiError.forbidden('Only the group owner can delete the group', 'NOT_OWNER');
  }
  if (group.conversationId) {
    await Conversation.deleteOne({ _id: group.conversationId });
    await Message.deleteMany({ conversationId: group.conversationId });
  }
  await group.deleteOne();
  return { deleted: true, conversationId: group.conversationId };
}

module.exports = {
  createGroup,
  getGroupForUser,
  updateGroup,
  addMembers,
  removeMember,
  setAdmin,
  deleteGroup,
  isAdmin,
};
