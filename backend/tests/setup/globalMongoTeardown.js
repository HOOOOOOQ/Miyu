'use strict';

/**
 * Jest globalTeardown: stops an in-memory mongod started by globalMongo.js.
 * An external server (MONGODB_URI_TEST) is owned by the caller, not by us.
 */
const fs = require('fs');
const path = require('path');

const HANDSHAKE_FILE = path.join(__dirname, '..', '..', '.jest', 'mongo.json');

module.exports = async () => {
  let payload = null;
  try {
    payload = JSON.parse(fs.readFileSync(HANDSHAKE_FILE, 'utf8'));
  } catch (_) {
    payload = null;
  }
  const mongod = globalThis.__MIYU_MONGOD__;
  if (payload && payload.source === 'memory' && mongod) {
    try {
      await mongod.stop();
    } catch (_) {
      /* best effort */
    }
  }
  try {
    fs.unlinkSync(HANDSHAKE_FILE);
  } catch (_) {
    /* already gone */
  }
};
