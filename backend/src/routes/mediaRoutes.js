'use strict';

const express = require('express');
const mediaController = require('../controllers/mediaController');
const { requireAuth } = require('../middleware/auth');
const { upload, handleMulterError } = require('../middleware/upload');
const { uploadLimiter } = require('../middleware/rateLimit');

const router = express.Router();

router.use(requireAuth);

router.post('/upload', uploadLimiter, upload.single('file'), handleMulterError, mediaController.uploadMedia);
router.post('/signature', uploadLimiter, mediaController.uploadSignature);

module.exports = router;
