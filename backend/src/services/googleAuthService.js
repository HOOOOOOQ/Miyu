'use strict';

const { OAuth2Client } = require('google-auth-library');
const { env } = require('../config/env');
const ApiError = require('../utils/ApiError');

let client = null;

function getClient() {
  if (!client) client = new OAuth2Client(env.googleClientId || undefined);
  return client;
}

/**
 * Verifies a Google ID token using Google's official library.
 * Returns { googleId, email, name, picture, emailVerified }.
 * Throws ApiError.unauthorized on any invalid token.
 */
async function verifyGoogleIdToken(idToken) {
  if (!idToken || typeof idToken !== 'string') {
    throw ApiError.badRequest('idToken is required', 'MISSING_ID_TOKEN');
  }
  if (!env.googleClientId) {
    throw ApiError.internal(
      'Google authentication is not configured on the server (GOOGLE_CLIENT_ID missing)',
      'GOOGLE_AUTH_NOT_CONFIGURED'
    );
  }
  let ticket;
  try {
    ticket = await getClient().verifyIdToken({
      idToken,
      audience: env.googleClientId,
    });
  } catch (_err) {
    throw ApiError.unauthorized('Invalid Google ID token', 'INVALID_GOOGLE_TOKEN');
  }
  const payload = ticket.getPayload();
  if (!payload || !payload.sub || !payload.email) {
    throw ApiError.unauthorized('Google token payload is incomplete', 'INVALID_GOOGLE_TOKEN');
  }
  if (payload.email_verified === false) {
    throw ApiError.unauthorized('Google account email is not verified', 'EMAIL_NOT_VERIFIED');
  }
  return {
    googleId: payload.sub,
    email: String(payload.email).toLowerCase(),
    name: payload.name || String(payload.email).split('@')[0],
    picture: payload.picture || null,
    emailVerified: payload.email_verified !== false,
  };
}

module.exports = { verifyGoogleIdToken };
