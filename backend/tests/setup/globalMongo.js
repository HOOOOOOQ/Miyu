'use strict';

/**
 * Jest globalSetup: prepares the test database once per run.
 *
 * Resolution order:
 *   1. MONGODB_URI_TEST  — use an external MongoDB (CI service container).
 *   2. mongodb-memory-server — download/cache a mongod binary (local dev).
 *
 * The outcome is written to a handshake file so each test file can decide,
 * synchronously at collection time, whether to `describe` or `describe.skip`.
 * That keeps the report honest: skipped suites show as skipped instead of
 * silently passing.
 */
const fs = require('fs');
const path = require('path');

const HANDSHAKE_DIR = path.join(__dirname, '..', '..', '.jest');
const HANDSHAKE_FILE = path.join(HANDSHAKE_DIR, 'mongo.json');

function writeHandshake(payload) {
  fs.mkdirSync(HANDSHAKE_DIR, { recursive: true });
  fs.writeFileSync(HANDSHAKE_FILE, JSON.stringify(payload), 'utf8');
}

module.exports = async () => {
  if (process.env.MONGODB_URI_TEST) {
    writeHandshake({ uri: process.env.MONGODB_URI_TEST, source: 'external' });
    return;
  }
  try {
    // Lazily required so an unreachable download host cannot slow unit-only runs.
    const { MongoMemoryServer } = require('mongodb-memory-server');
    const mongod = await MongoMemoryServer.create();
    writeHandshake({ uri: mongod.getUri(), source: 'memory', pid: process.pid });
    globalThis.__MIYU_MONGOD__ = mongod;
  } catch (err) {
    const message = `[test] no MongoDB available: ${err.message}`;
    if (process.env.MIYU_REQUIRE_DB === '1') throw new Error(message);
    writeHandshake({ uri: null, error: message });
    // eslint-disable-next-line no-console
    console.warn(`${message} — DB suites will be reported as skipped`);
  }
};
