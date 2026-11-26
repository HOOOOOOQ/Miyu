'use strict';

const mongoose = require('mongoose');
const { User, BlockedUser, Report, Conversation, Message } = require('../models');
const catchAsync = require('../utils/catchAsync');
const ApiError = require('../utils/ApiError');
const notificationService = require('../services/notificationService');

function sanitizeSearchTerm(term) {
  return String(term).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const getMe = catchAsync(async (req, res) => {
  const blocked = await BlockedUser.find({ blocker: req.user._id })
    .populate('blocked', 'displayName username photoURL')
    .lean();
  res.json({
    success: true,
    data: {
      user: req.user.toPublic(),
      blockedUsers: blocked
        .filter((b) => b.blocked)
        .map((b) => ({
          id: b.blocked._id.toString(),
          displayName: b.blocked.displayName,
          username: b.blocked.username,
          photoURL: b.blocked.photoURL,
          blockedAt: b.createdAt,
        })),
    },
  });
});

const getUserById = catchAsync(async (req, res) => {
  if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
    throw ApiError.badRequest('Invalid user id', 'INVALID_ID');
  }
  const user = await User.findById(req.params.id);
  if (!user) throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
  const profile = user.toPublic();
  if (!user.showLastSeen) profile.lastSeen = null;
  if (!user.showOnlineStatus) profile.isOnline = false;
  // Hide email from other users.
  delete profile.email;
  const iBlocked = await BlockedUser.exists({ blocker: req.user._id, blocked: user._id });
  const blockedMe = await BlockedUser.exists({ blocker: user._id, blocked: req.user._id });
  res.json({
    success: true,
    data: { user: profile, iBlockedThem: Boolean(iBlocked), theyBlockedMe: Boolean(blockedMe) },
  });
});

const searchUsers = catchAsync(async (req, res) => {
  const q = sanitizeSearchTerm(req.validatedQuery.q || req.query.q);
  const limit = Math.min(Number(req.validatedQuery?.limit || req.query.limit || 20), 50);
  const blocked = await BlockedUser.find({
    $or: [{ blocker: req.user._id }, { blocked: req.user._id }],
  }).lean();
  const excluded = new Set();
  blocked.forEach((b) => {
    excluded.add(b.blocker.toString());
    excluded.add(b.blocked.toString());
  });
  excluded.add(req.user._id.toString());

  const regex = new RegExp(q, 'i');
  const users = await User.find({
    _id: { $nin: [...excluded] },
    $or: [{ displayName: regex }, { username: regex }, { email: regex }],
  })
    .select('displayName username photoURL bio isOnline lastSeen showOnlineStatus showLastSeen')
    .limit(limit)
    .lean();

  res.json({
    success: true,
    data: {
      users: users.map((u) => ({
        id: u._id.toString(),
        displayName: u.displayName,
        username: u.username,
        photoURL: u.photoURL,
        bio: u.bio,
        isOnline: u.showOnlineStatus ? u.isOnline : false,
        lastSeen: u.showLastSeen ? u.lastSeen : null,
      })),
    },
  });
});

const updateMe = catchAsync(async (req, res) => {
  const updates = req.body;
  if (updates.username) {
    const existing = await User.findOne({
      username: updates.username,
      _id: { $ne: req.user._id },
    });
    if (existing) throw ApiError.conflict('That username is already taken', 'USERNAME_TAKEN');
  }
  Object.assign(req.user, updates);
  await req.user.save();
  res.json({ success: true, data: { user: req.user.toPublic() } });
});

const blockUser = catchAsync(async (req, res) => {
  const targetId = req.params.id;
  if (!mongoose.Types.ObjectId.isValid(targetId)) {
    throw ApiError.badRequest('Invalid user id', 'INVALID_ID');
  }
  if (String(targetId) === String(req.user._id)) {
    throw ApiError.badRequest('You cannot block yourself', 'SELF_BLOCK');
  }
  const target = await User.findById(targetId);
  if (!target) throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
  await BlockedUser.findOneAndUpdate(
    { blocker: req.user._id, blocked: targetId },
    { $setOnInsert: { reason: req.body.reason || '' } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  res.json({ success: true, data: { blocked: true, userId: targetId } });
});

const unblockUser = catchAsync(async (req, res) => {
  await BlockedUser.deleteOne({ blocker: req.user._id, blocked: req.params.id });
  res.json({ success: true, data: { unblocked: true, userId: req.params.id } });
});

const reportUser = catchAsync(async (req, res) => {
  const target = await User.findById(req.params.id);
  if (!target) throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
  const report = await Report.create({
    reporter: req.user._id,
    reportedUser: target._id,
    reason: req.body.reason,
  });
  res.status(201).json({ success: true, data: { reportId: report._id.toString() } });
});

const registerDevice = catchAsync(async (req, res) => {
  const { fcmToken, platform, deviceName } = req.body;
  await notificationService.registerDevice({
    userId: req.user._id,
    fcmToken,
    platform,
    deviceName,
  });
  res.json({ success: true, data: { registered: true } });
});

const unregisterDevice = catchAsync(async (req, res) => {
  await notificationService.unregisterDevice({
    userId: req.user._id,
    fcmToken: req.body.fcmToken,
  });
  res.json({ success: true, data: { unregistered: true } });
});

/** GDPR-style account deletion: wipes messages authored, conversations, groups links. */
const deleteMe = catchAsync(async (req, res) => {
  const userId = req.user._id;
  await Message.updateMany({ senderId: userId }, { $set: { content: '', deletedAt: new Date(), mediaUrl: null } });
  await Conversation.updateMany({ participants: userId }, { $pull: { participants: userId } });
  await Conversation.deleteMany({ participants: { $size: 0 } });
  await BlockedUser.deleteMany({ $or: [{ blocker: userId }, { blocked: userId }] });
  await notificationService.unregisterAllDevices(userId);
  await req.user.deleteOne();
  res.json({ success: true, data: { deleted: true } });
});

module.exports = {
  getMe,
  getUserById,
  searchUsers,
  updateMe,
  blockUser,
  unblockUser,
  reportUser,
  registerDevice,
  unregisterDevice,
  deleteMe,
};
