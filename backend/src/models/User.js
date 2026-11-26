'use strict';

const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    googleId: { type: String, required: true, unique: true, index: true },
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
      unique: true,
      index: true,
    },
    displayName: { type: String, required: true, trim: true, maxlength: 60 },
    username: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      minlength: 3,
      maxlength: 30,
      match: /^[a-z0-9_.]+$/,
      index: true,
    },
    photoURL: { type: String, default: null },
    bio: { type: String, default: '', maxlength: 200 },
    isOnline: { type: Boolean, default: false, index: true },
    lastSeen: { type: Date, default: Date.now },
    showOnlineStatus: { type: Boolean, default: true },
    showLastSeen: { type: Boolean, default: true },
    notificationsEnabled: { type: Boolean, default: true },
    fcmTokens: [{ type: String }],
    publicKey: { type: String, default: null },
  },
  { timestamps: true, versionKey: false }
);

userSchema.index({ displayName: 'text', username: 'text' });

userSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    googleId: this.googleId,
    email: this.email,
    displayName: this.displayName,
    username: this.username,
    photoURL: this.photoURL,
    bio: this.bio,
    isOnline: this.isOnline,
    lastSeen: this.lastSeen,
    showOnlineStatus: this.showOnlineStatus,
    showLastSeen: this.showLastSeen,
    notificationsEnabled: this.notificationsEnabled,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);
