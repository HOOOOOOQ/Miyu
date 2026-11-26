'use strict';

const { User, Conversation } = require('../../src/models');
const { issueTokenPair } = require('../../src/services/authService');

let counter = 0;

async function createUser(overrides = {}) {
  counter += 1;
  const n = counter;
  const user = await User.create({
    googleId: `google-${n}-${Date.now()}`,
    email: `user${n}-${Date.now()}@example.com`,
    displayName: `Test User ${n}`,
    username: `testuser${n}${Date.now().toString(36).slice(-4)}`,
    photoURL: null,
    isOnline: true,
    ...overrides,
  });
  return user;
}

async function authFor(user) {
  const tokens = await issueTokenPair(user, { family: undefined });
  return {
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    header: `Bearer ${tokens.accessToken}`,
  };
}

async function createDirectConversation(userA, userB) {
  return Conversation.create({
    conversationType: 'direct',
    participants: [userA._id, userB._id],
    createdBy: userA._id,
    lastActivity: new Date(),
    unreadCounts: { [String(userB._id)]: 0 },
  });
}

module.exports = { createUser, authFor, createDirectConversation };
