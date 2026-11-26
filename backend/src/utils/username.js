'use strict';

const User = require('../models/User');

const RESERVED = new Set(['admin', 'miyu', 'support', 'system', 'root', 'api', 'me', 'null']);

function sanitizeUsernameSeed(input) {
  const base = String(input || 'miyu')
    .toLowerCase()
    .replace(/[^a-z0-9_.]/g, '')
    .replace(/^[_.]+|[_.]+$/g, '')
    .slice(0, 22);
  return base.length >= 3 ? base : `miyu${base}`.slice(0, 22);
}

/**
 * Generates a unique username from a display name or email local-part.
 * Appends a numeric suffix on collisions.
 */
async function generateUniqueUsername(seed) {
  let base = sanitizeUsernameSeed(seed);
  if (RESERVED.has(base)) base = `${base}_miyu`;
  let candidate = base;
  let attempt = 0;
  // Bounded loop: 24 attempts max, then a random suffix guarantees uniqueness.
  while (attempt < 24) {
    const exists = await User.exists({ username: candidate });
    if (!exists) return candidate;
    attempt += 1;
    candidate = `${base}${attempt}`.slice(0, 30);
  }
  return `${base}${Date.now().toString(36)}`.slice(0, 30);
}

module.exports = { generateUniqueUsername, sanitizeUsernameSeed, RESERVED };
