'use strict';

const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');

function signAccessToken(user) {
  if (!env.jwtAccessSecret) throw new Error('JWT_ACCESS_SECRET is not configured');
  return jwt.sign(
    { sub: user._id.toString(), type: 'access', username: user.username },
    env.jwtAccessSecret,
    { expiresIn: env.jwtAccessExpiresIn, issuer: 'miyu' }
  );
}

function signRefreshTokenValue(user, family) {
  if (!env.jwtRefreshSecret) throw new Error('JWT_REFRESH_SECRET is not configured');
  return jwt.sign(
    {
      sub: user._id.toString(),
      type: 'refresh',
      family,
      // Without a per-token nonce, two rotations inside the same second produce
      // byte-identical JWTs (same iat/exp/sub). The unique tokenHash index then
      // rejects the second insert with E11000 and refresh fails with HTTP 409.
      jti: crypto.randomBytes(16).toString('hex'),
    },
    env.jwtRefreshSecret,
    { expiresIn: env.jwtRefreshExpiresIn, issuer: 'miyu' }
  );
}

function verifyAccessToken(token) {
  const payload = jwt.verify(token, env.jwtAccessSecret, { issuer: 'miyu' });
  if (payload.type !== 'access') throw new Error('Invalid token type');
  return payload;
}

function verifyRefreshToken(token) {
  const payload = jwt.verify(token, env.jwtRefreshSecret, { issuer: 'miyu' });
  if (payload.type !== 'refresh') throw new Error('Invalid token type');
  return payload;
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function newTokenFamily() {
  return crypto.randomBytes(16).toString('hex');
}

/** Parse a duration like "30d", "15m", "12h" into milliseconds. */
function durationToMs(value, fallbackMs) {
  const m = /^(\d+)([smhd])$/.exec(String(value || '').trim());
  if (!m) return fallbackMs;
  const n = Number(m[1]);
  const unit = { s: 1000, m: 60000, h: 3600000, d: 86400000 }[m[2]];
  return n * unit;
}

module.exports = {
  signAccessToken,
  signRefreshTokenValue,
  verifyAccessToken,
  verifyRefreshToken,
  hashToken,
  newTokenFamily,
  durationToMs,
};
