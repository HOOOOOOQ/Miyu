'use strict';

const mongoose = require('mongoose');

const deviceSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    fcmToken: { type: String, required: true, unique: true },
    platform: { type: String, default: 'android' },
    deviceName: { type: String, default: null },
    lastActiveAt: { type: Date, default: Date.now },
  },
  { timestamps: true, versionKey: false }
);

deviceSchema.index({ user: 1, fcmToken: 1 });

module.exports = mongoose.model('Device', deviceSchema);
