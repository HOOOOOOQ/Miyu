'use strict';

const admin = require('firebase-admin');
const { env } = require('./env');
const logger = require('./logger');

let initialized = false;

function initFirebase() {
  if (initialized) return admin;
  if (!env.firebaseServiceAccountJson) {
    logger.warn('[firebase] FIREBASE_SERVICE_ACCOUNT_JSON not set — FCM disabled');
    return admin;
  }
  try {
    let credential;
    const raw = env.firebaseServiceAccountJson;
    // Accept either raw JSON string or base64-encoded JSON.
    try {
      credential = admin.credential.cert(JSON.parse(raw));
    } catch (_e) {
      const decoded = Buffer.from(raw, 'base64').toString('utf8');
      credential = admin.credential.cert(JSON.parse(decoded));
    }
    admin.initializeApp({ credential, projectId: env.firebaseProjectId || undefined });
    initialized = true;
    logger.info('[firebase] Firebase Admin initialized');
  } catch (err) {
    logger.error({ err: err.message }, '[firebase] Failed to initialize Firebase Admin');
  }
  return admin;
}

function isInitialized() {
  return initialized;
}

module.exports = { admin, initFirebase, isInitialized };
