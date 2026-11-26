'use strict';

const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: {
      type: String,
      enum: ['message', 'group_message', 'incoming_call', 'missed_call', 'group_invite', 'reaction'],
      required: true,
    },
    title: { type: String, required: true },
    body: { type: String, default: '' },
    data: { type: Object, default: {} },
    read: { type: Boolean, default: false, index: true },
  },
  { timestamps: true, versionKey: false }
);

notificationSchema.index({ user: 1, createdAt: -1 });

notificationSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    user: this.user.toString(),
    type: this.type,
    title: this.title,
    body: this.body,
    data: this.data,
    read: this.read,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('Notification', notificationSchema);
