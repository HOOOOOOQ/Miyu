'use strict';

const rateLimit = require('express-rate-limit');

function makeLimiter({ windowMs, max, message }) {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    // Tests hit the same process repeatedly; disable counting there.
    skip: () => process.env.NODE_ENV === 'test',
    handler: (_req, res) => {
      res.status(429).json({
        success: false,
        error: { code: 'RATE_LIMITED', message: message || 'Too many requests, please try again later' },
      });
    },
  });
}

const apiLimiter = makeLimiter({ windowMs: 60_000, max: 300 });
const authLimiter = makeLimiter({
  windowMs: 15 * 60_000,
  max: 40,
  message: 'Too many authentication attempts, try again later',
});
const uploadLimiter = makeLimiter({ windowMs: 60_000, max: 30 });

module.exports = { apiLimiter, authLimiter, uploadLimiter, makeLimiter };
