'use strict';

const authService = require('../services/authService');
const notificationService = require('../services/notificationService');
const { User } = require('../models');
const catchAsync = require('../utils/catchAsync');

const googleLogin = catchAsync(async (req, res) => {
  const { idToken, deviceName } = req.body;
  const { user, tokens, isNewUser } = await authService.loginWithGoogle({
    idToken,
    deviceName,
    userAgent: req.headers['user-agent'] || null,
  });
  res.json({
    success: true,
    data: {
      user: user.toPublic(),
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      isNewUser,
    },
  });
});

const refresh = catchAsync(async (req, res) => {
  const { refreshToken } = req.body;
  const { user, tokens } = await authService.rotateRefreshToken({
    refreshToken,
    userAgent: req.headers['user-agent'] || null,
  });
  res.json({
    success: true,
    data: {
      user: user.toPublic(),
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    },
  });
});

const logout = catchAsync(async (req, res) => {
  const { refreshToken, fcmToken } = req.body || {};
  await authService.revokeRefreshToken({ refreshToken });
  if (fcmToken) {
    await notificationService.unregisterDevice({ userId: req.user._id, fcmToken });
  }
  await User.updateOne(
    { _id: req.user._id },
    { $set: { isOnline: false, lastSeen: new Date() } }
  );
  res.json({ success: true, data: { loggedOut: true } });
});

module.exports = { googleLogin, refresh, logout };
