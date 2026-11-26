'use strict';

require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });

function required(name) {
  const v = process.env[name];
  if (!v || String(v).trim() === '') {
    return null;
  }
  return String(v).trim();
}

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 5000),
  apiBaseUrl: process.env.API_BASE_URL || `http://localhost:${process.env.PORT || 5000}`,
  mongoUri: required('MONGODB_URI'),
  jwtAccessSecret: required('JWT_ACCESS_SECRET'),
  jwtRefreshSecret: required('JWT_REFRESH_SECRET'),
  jwtAccessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  googleClientId: required('GOOGLE_CLIENT_ID'),
  googleClientSecret: required('GOOGLE_CLIENT_SECRET'),
  turnUrl: required('TURN_URL'),
  turnUsername: required('TURN_USERNAME'),
  turnCredential: required('TURN_CREDENTIAL'),
  cloudinaryCloudName: required('CLOUDINARY_CLOUD_NAME'),
  cloudinaryApiKey: required('CLOUDINARY_API_KEY'),
  cloudinaryApiSecret: required('CLOUDINARY_API_SECRET'),
  firebaseProjectId: required('FIREBASE_PROJECT_ID'),
  firebaseServiceAccountJson: required('FIREBASE_SERVICE_ACCOUNT_JSON'),
  corsOrigins: (process.env.CORS_ORIGINS || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  maxFileSizeMb: Number(process.env.MAX_FILE_SIZE_MB || 25),
};

function validateEnv() {
  const missing = [];
  if (!env.mongoUri) missing.push('MONGODB_URI');
  if (!env.jwtAccessSecret) missing.push('JWT_ACCESS_SECRET');
  if (!env.jwtRefreshSecret) missing.push('JWT_REFRESH_SECRET');
  if (!env.googleClientId) missing.push('GOOGLE_CLIENT_ID');
  if (missing.length > 0) {
    // In test environment, allow boot without secrets so unit tests can run.
    if (env.nodeEnv === 'test') return;
    // eslint-disable-next-line no-console
    console.warn(
      `[env] Missing required env vars: ${missing.join(', ')}. ` +
        'API will start but authenticated routes will fail until configured. See backend/.env.example'
    );
  }
}

module.exports = { env, validateEnv };
