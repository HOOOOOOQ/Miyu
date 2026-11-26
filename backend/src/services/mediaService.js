'use strict';

const { cloudinary, isConfigured } = require('../config/cloudinary');
const { env } = require('../config/env');
const ApiError = require('../utils/ApiError');
const logger = require('../config/logger');

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const VIDEO_TYPES = ['video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp'];
const AUDIO_TYPES = ['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/webm', 'audio/wav', 'audio/x-m4a'];
const FILE_TYPES = [
  'application/pdf',
  'application/zip',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
  'application/octet-stream',
];

const ALLOWED_TYPES = new Set([...IMAGE_TYPES, ...VIDEO_TYPES, ...AUDIO_TYPES, ...FILE_TYPES]);

function detectResourceType(mimeType) {
  if (IMAGE_TYPES.includes(mimeType)) return 'image';
  if (VIDEO_TYPES.includes(mimeType) || AUDIO_TYPES.includes(mimeType)) return 'video';
  return 'raw';
}

function assertUploadAllowed(file) {
  if (!file) throw ApiError.badRequest('No file provided', 'NO_FILE');
  if (env.nodeEnv === 'test' && !file.mimetype) return;
  const maxBytes = env.maxFileSizeMb * 1024 * 1024;
  if (file.size > maxBytes) {
    throw ApiError.badRequest(
      `File exceeds the ${env.maxFileSizeMb}MB limit`,
      'FILE_TOO_LARGE'
    );
  }
  if (file.mimetype && !ALLOWED_TYPES.has(file.mimetype)) {
    throw ApiError.badRequest(`File type ${file.mimetype} is not allowed`, 'FILE_TYPE_NOT_ALLOWED');
  }
}

/**
 * Uploads a multer buffer to Cloudinary using an authenticated signature
 * generated server-side. Credentials never leave the backend.
 */
function uploadBuffer(file, { folder = 'miyu/uploads' } = {}) {
  assertUploadAllowed(file);
  if (!isConfigured()) {
    throw ApiError.internal(
      'Media storage is not configured (Cloudinary env vars missing)',
      'MEDIA_NOT_CONFIGURED'
    );
  }
  const resourceType = detectResourceType(file.mimetype || 'application/octet-stream');
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder,
        resource_type: resourceType,
        use_filename: true,
        unique_filename: true,
        overwrite: false,
      },
      (err, result) => {
        if (err) {
          logger.error({ err: err.message }, '[media] cloudinary upload failed');
          return reject(ApiError.internal('Media upload failed', 'UPLOAD_FAILED'));
        }
        return resolve({
          url: result.secure_url,
          publicId: result.public_id,
          resourceType: result.resource_type,
          format: result.format || null,
          bytes: result.bytes,
          width: result.width || null,
          height: result.height || null,
          duration: result.duration || null,
          originalName: file.originalname,
          mimeType: file.mimetype,
        });
      }
    );
    stream.end(file.buffer);
  });
}

/**
 * A signed direct-upload payload for larger client-side uploads.
 * The client posts straight to Cloudinary; the API secret stays on the server.
 */
function createUploadSignature({ folder = 'miyu/uploads', resourceType = 'auto' } = {}) {
  if (!isConfigured()) {
    throw ApiError.internal('Media storage is not configured', 'MEDIA_NOT_CONFIGURED');
  }
  const timestamp = Math.round(Date.now() / 1000);
  const params = { folder, timestamp };
  const signature = cloudinary.utils.api_sign_request(params, env.cloudinaryApiSecret);
  return {
    cloudName: env.cloudinaryCloudName,
    apiKey: env.cloudinaryApiKey,
    timestamp,
    folder,
    signature,
    uploadUrl: `https://api.cloudinary.com/v1_1/${env.cloudinaryCloudName}/${resourceType}/upload`,
  };
}

function getIceServers() {
  const servers = [{ urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'] }];
  if (env.turnUrl && env.turnUsername && env.turnCredential) {
    servers.push({
      urls: env.turnUrl.split(',').map((u) => u.trim()).filter(Boolean),
      username: env.turnUsername,
      credential: env.turnCredential,
    });
  }
  return servers;
}

module.exports = {
  uploadBuffer,
  assertUploadAllowed,
  createUploadSignature,
  getIceServers,
  detectResourceType,
  ALLOWED_TYPES,
  IMAGE_TYPES,
  VIDEO_TYPES,
  AUDIO_TYPES,
};
