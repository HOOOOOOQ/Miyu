'use strict';

const mongoose = require('mongoose');

const blockedUserSchema = new mongoose.Schema(
  {
    blocker: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    blocked: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    reason: { type: String, default: '', maxlength: 300 },
  },
  { timestamps: true, versionKey: false }
);

blockedUserSchema.index({ blocker: 1, blocked: 1 }, { unique: true });

blockedUserSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    blocker: this.blocker.toString(),
    blocked: this.blocked.toString(),
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('BlockedUser', blockedUserSchema);
