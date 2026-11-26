'use strict';

const { verifyAccessToken } = require('../utils/tokens');
const { User } = require('../models');
const ApiError = require('../utils/ApiError');
const catchAsync = require('../utils/catchAsync');

/**
 * Requires a valid Bearer access token. Attaches req.user (Mongoose doc).
 */
const requireAuth = catchAsync(async (req, _res, next) => {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    throw ApiError.unauthorized('Authentication required', 'MISSING_TOKEN');
  }
  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (_err) {
    throw ApiError.unauthorized('Invalid or expired access token', 'INVALID_TOKEN');
  }
  const user = await User.findById(payload.sub);
  if (!user) throw ApiError.unauthorized('User no longer exists', 'USER_NOT_FOUND');
  req.user = user;
  req.auth = payload;
  next();
});

module.exports = { requireAuth };
