'use strict';

const mediaService = require('../services/mediaService');
const catchAsync = require('../utils/catchAsync');
const ApiError = require('../utils/ApiError');

const uploadMedia = catchAsync(async (req, res) => {
  if (!req.file) throw ApiError.badRequest('No file uploaded', 'NO_FILE');
  const result = await mediaService.uploadBuffer(req.file, {
    folder: `miyu/${req.user._id}`,
  });
  res.status(201).json({ success: true, data: result });
});

const uploadSignature = catchAsync(async (req, res) => {
  const signature = mediaService.createUploadSignature({
    folder: `miyu/${req.user._id}`,
    resourceType: req.body.resourceType === 'video' ? 'video' : req.body.resourceType === 'raw' ? 'raw' : 'auto',
  });
  res.json({ success: true, data: signature });
});

const iceServers = catchAsync(async (_req, res) => {
  res.json({ success: true, data: { iceServers: mediaService.getIceServers() } });
});

module.exports = { uploadMedia, uploadSignature, iceServers };
