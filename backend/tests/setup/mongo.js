'use strict';

/**
 * Shared test database helper.
 *
 * The URI is resolved once by jest globalSetup (see globalMongo.js) and read
 * here synchronously, so suites can be excluded at collection time when no
 * MongoDB is available. Set MONGODB_URI_TEST to point at a real server and
 * MIYU_REQUIRE_DB=1 to turn "missing database" into a hard failure.
 */
process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test-access-secret-'.padEnd(32, 'a');
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'test-refresh-secret-'.padEnd(32, 'b');
process.env.JWT_ACCESS_EXPIRES_IN = '15m';
process.env.JWT_REFRESH_EXPIRES_IN = '30d';
process.env.GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || 'test-client.apps.googleusercontent.com';

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

const HANDSHAKE_FILE = path.join(__dirname, '..', '..', '.jest', 'mongo.json');

function readHandshake() {
  try {
    return JSON.parse(fs.readFileSync(HANDSHAKE_FILE, 'utf8'));
  } catch (_) {
    return { uri: null, error: '[test] jest globalSetup did not run' };
  }
}

const handshake = readHandshake();
const uri = handshake.uri || null;
const available = Boolean(uri);

if (!available && process.env.MIYU_REQUIRE_DB === '1') {
  throw new Error(handshake.error || '[test] MongoDB is required but unavailable');
}

/** True when a database is reachable; suites should use describe.skip otherwise. */
const isConfigured = available;

async function connect() {
  if (!available) return null;
  if (mongoose.connection.readyState === 1) return mongoose.connection;
  await mongoose.connect(uri, { dbName: 'miyu_test' });
  return mongoose.connection;
}

async function clearDatabase() {
  if (!available || mongoose.connection.readyState !== 1) return;
  const collections = await mongoose.connection.db.collections();
  await Promise.all(collections.map((c) => c.deleteMany({})));
}

async function disconnect() {
  if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
}

module.exports = { connect, clearDatabase, disconnect, isConfigured, uri };
