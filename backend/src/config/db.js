'use strict';

const mongoose = require('mongoose');
const { env } = require('./env');

let connected = false;

async function connectDB() {
  if (!env.mongoUri) {
    // eslint-disable-next-line no-console
    console.warn('[db] MONGODB_URI not set — skipping MongoDB connection (unit-test mode).');
    return null;
  }
  mongoose.set('strictQuery', true);
  try {
    await mongoose.connect(env.mongoUri, {
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
    });
    connected = true;
    // eslint-disable-next-line no-console
    console.log('[db] MongoDB connected');
    return mongoose.connection;
  } catch (err) {
    // Never log the URI itself.
    // eslint-disable-next-line no-console
    console.error(`[db] MongoDB connection failed: ${err.message}`);
    throw err;
  }
}

function isConnected() {
  return connected && mongoose.connection.readyState === 1;
}

async function disconnectDB() {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
  connected = false;
}

module.exports = { connectDB, disconnectDB, isConnected };
