'use strict';

const mongoose = require('mongoose');
const { env } = require('./env');

let connected = false;

/**
 * Pterodactyl @ 3186 production behaviour: start listening immediately, then
 * retry the database in the background. Blocking boot on Mongo would make the
 * panel's health check fail (and can trigger a restart loop) whenever Atlas is
 * briefly unreachable or the container starts before the DB is awake.
 */
const RECONNECT_DELAY_MS = 15_000;
let retryTimer = null;

function scheduleReconnect() {
  if (retryTimer) return;
  retryTimer = setTimeout(() => {
    retryTimer = null;
    connectDB().catch(() => {});
  }, RECONNECT_DELAY_MS);
  if (retryTimer.unref) retryTimer.unref();
}

async function connectDB() {
  if (!env.mongoUri) {
    // eslint-disable-next-line no-console
    console.warn('[db] MONGODB_URI not set — skipping MongoDB connection (unit-test mode).');
    return null;
  }
  mongoose.set('strictQuery', true);
  try {
    await mongoose.connect(env.mongoUri, {
      // Fail fast so a wrong URI is visible in the panel console instead of
      // hanging for the default 30s while the container looks half-dead.
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
    });
    connected = true;
    if (retryTimer) {
      clearTimeout(retryTimer);
      retryTimer = null;
    }
    // eslint-disable-next-line no-console
    console.log('[db] MongoDB connected');
    return mongoose.connection;
  } catch (err) {
    // Never log the URI itself.
    // eslint-disable-next-line no-console
    console.error(`[db] MongoDB connection failed: ${err.message}`);
    console.error(`[db] retrying in ${RECONNECT_DELAY_MS / 1000}s — check MONGODB_URI and Atlas IP allow-list`);
    scheduleReconnect();
    throw err;
  }
}

function isConnected() {
  return connected && mongoose.connection.readyState === 1;
}

async function disconnectDB() {
  if (retryTimer) {
    clearTimeout(retryTimer);
    retryTimer = null;
  }
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
  connected = false;
}

module.exports = { connectDB, disconnectDB, isConnected };

