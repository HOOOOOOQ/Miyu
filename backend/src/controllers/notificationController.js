'use strict';

const { Notification } = require('../models');
const catchAsync = require('../utils/catchAsync');
const ApiError = require('../utils/ApiError');

const listNotifications = catchAsync(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 100);
  const notifications = await Notification.find({ user: req.user._id })
    .sort({ createdAt: -1 })
    .limit(limit);
  const unread = await Notification.countDocuments({ user: req.user._id, read: false });
  res.json({
    success: true,
    data: { notifications: notifications.map((n) => n.toPublic()), unread },
  });
});

const markRead = catchAsync(async (req, res) => {
  const result = await Notification.updateOne(
    { _id: req.params.id, user: req.user._id },
    { $set: { read: true } }
  );
  if (!result.matchedCount) throw ApiError.notFound('Notification not found', 'NOTIFICATION_NOT_FOUND');
  res.json({ success: true, data: { read: true } });
});

const markAllRead = catchAsync(async (req, res) => {
  await Notification.updateMany({ user: req.user._id, read: false }, { $set: { read: true } });
  res.json({ success: true, data: { read: true } });
});

module.exports = { listNotifications, markRead, markAllRead };
