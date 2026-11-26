'use strict';

const multer = require('multer');
const { env } = require('../config/env');
const ApiError = require('../utils/ApiError');

const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: {
    fileSize: env.maxFileSizeMb * 1024 * 1024,
    files: 1,
  },
  fileFilter: (_req, file, cb) => {
    // Type allow-list is enforced again in mediaService before upload.
    if (!file.mimetype) return cb(new ApiError(400, 'File type could not be detected', 'INVALID_FILE'));
    return cb(null, true);
  },
});

function handleMulterError(err, _req, res, next) {
  if (err instanceof multer.MulterError) {
    const message =
      err.code === 'LIMIT_FILE_SIZE'
        ? `File exceeds the ${env.maxFileSizeMb}MB limit`
        : `Upload rejected: ${err.code}`;
    return res.status(400).json({ success: false, error: { code: err.code, message } });
  }
  return next(err);
}

module.exports = { upload, handleMulterError };
