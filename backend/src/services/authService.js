'use strict';

const crypto = require('crypto');
const { env } = require('../config/env');
const { User, RefreshToken } = require('../models');
const { verifyGoogleIdToken } = require('./googleAuthService');
const { generateUniqueUsername } = require('../utils/username');
const {
  signAccessToken,
  signRefreshTokenValue,
  verifyRefreshToken,
  hashToken,
  newTokenFamily,
  durationToMs,
} = require('../utils/tokens');
const ApiError = require('../utils/ApiError');
const logger = require('../config/logger');

const REFRESH_TTL_FALLBACK_MS = 30 * 24 * 60 * 60 * 1000;

async function issueTokenPair(user, { family, userAgent }) {
  const accessToken = signAccessToken(user);
  const tokenFamily = family || newTokenFamily();
  const refreshToken = signRefreshTokenValue(user, tokenFamily);
  const expiresAt = new Date(
    Date.now() + durationToMs(env.jwtRefreshExpiresIn, REFRESH_TTL_FALLBACK_MS)
  );
  await RefreshToken.create({
    user: user._id,
    tokenHash: hashToken(refreshToken),
    family: tokenFamily,
    expiresAt,
    userAgent: userAgent || null,
  });
  return { accessToken, refreshToken, tokenFamily };
}

/**
 * Full Google login: verify token → find or create user → issue tokens.
 */
async function loginWithGoogle({ idToken, deviceName, userAgent }) {
  const profile = await verifyGoogleIdToken(idToken);
  let user = await User.findOne({ googleId: profile.googleId });
  let isNewUser = false;

  if (!user) {
    // An account may exist from a previous auth method keyed on email.
    user = await User.findOne({ email: profile.email });
    if (user) {
      user.googleId = profile.googleId;
      if (!user.photoURL && profile.picture) user.photoURL = profile.picture;
      await user.save();
    } else {
      const username = await generateUniqueUsername(profile.email.split('@')[0] || profile.name);
      try {
        user = await User.create({
          googleId: profile.googleId,
          email: profile.email,
          displayName: profile.name,
          username,
          photoURL: profile.picture,
          lastSeen: new Date(),
        });
        isNewUser = true;
      } catch (err) {
        if (err && err.code === 11000) {
          // Race on concurrent first login — fetch the winner's record.
          user = await User.findOne({ googleId: profile.googleId });
          if (!user) throw ApiError.conflict('Account creation conflict, please retry', 'ACCOUNT_CONFLICT');
        } else {
          throw err;
        }
      }
    }
  }

  user.isOnline = true;
  user.lastSeen = new Date();
  await user.save();

  const tokens = await issueTokenPair(user, { userAgent, deviceName });
  logger.info({ userId: user._id.toString(), isNewUser }, '[auth] google login');
  return { user, tokens, isNewUser };
}

/**
 * Rotating refresh: every use revokes the presented token and issues a new pair.
 * Reuse of an already-revoked token revokes the whole family (theft detection).
 */
async function rotateRefreshToken({ refreshToken, userAgent }) {
  if (!refreshToken) throw ApiError.badRequest('refreshToken is required', 'MISSING_REFRESH_TOKEN');
  try {
    verifyRefreshToken(refreshToken);
  } catch (_err) {
    throw ApiError.unauthorized('Invalid or expired refresh token', 'INVALID_REFRESH_TOKEN');
  }
  const tokenHash = hashToken(refreshToken);
  const stored = await RefreshToken.findOne({ tokenHash });
  if (!stored) {
    // Token signed by us but unknown: assume revocation.
    throw ApiError.unauthorized('Refresh token revoked', 'REFRESH_TOKEN_REVOKED');
  }
  if (stored.revokedAt) {
    // Token reuse — kill the family.
    await RefreshToken.updateMany(
      { family: stored.family, revokedAt: null },
      { $set: { revokedAt: new Date() } }
    );
    logger.warn({ userId: stored.user.toString() }, '[auth] refresh token reuse detected — family revoked');
    throw ApiError.unauthorized('Refresh token reuse detected', 'REFRESH_TOKEN_REUSE');
  }
  if (stored.expiresAt.getTime() < Date.now()) {
    throw ApiError.unauthorized('Refresh token expired', 'REFRESH_TOKEN_EXPIRED');
  }
  const user = await User.findById(stored.user);
  if (!user) throw ApiError.unauthorized('User no longer exists', 'USER_NOT_FOUND');

  const next = await issueTokenPair(user, { family: stored.family, userAgent });
  stored.revokedAt = new Date();
  stored.replacedBy = hashToken(next.refreshToken);
  await stored.save();

  return { user, tokens: next };
}

async function revokeRefreshToken({ refreshToken }) {
  if (!refreshToken) return;
  const tokenHash = hashToken(refreshToken);
  await RefreshToken.updateOne({ tokenHash, revokedAt: null }, { $set: { revokedAt: new Date() } });
}

async function revokeAllForUser(userId) {
  await RefreshToken.updateMany({ user: userId, revokedAt: null }, { $set: { revokedAt: new Date() } });
}

module.exports = {
  loginWithGoogle,
  rotateRefreshToken,
  revokeRefreshToken,
  revokeAllForUser,
  issueTokenPair,
};

// Exported for tests
module.exports._hashToken = (t) => crypto.createHash('sha256').update(t).digest('hex');
