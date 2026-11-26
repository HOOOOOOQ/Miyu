'use strict';

const mongoose = require('mongoose');

const callSchema = new mongoose.Schema(
  {
    callerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    receiverIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true }],
    conversationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Conversation', default: null },
    callType: { type: String, enum: ['voice', 'video'], required: true },
    status: {
      type: String,
      enum: ['ringing', 'ongoing', 'answered', 'ended', 'missed', 'rejected', 'cancelled', 'busy', 'failed'],
      default: 'ringing',
      index: true,
    },
    startedAt: { type: Date, default: Date.now },
    answeredAt: { type: Date, default: null },
    endedAt: { type: Date, default: null },
    duration: { type: Number, default: 0 },
    endedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  },
  { timestamps: true, versionKey: false }
);

callSchema.index({ callerId: 1, createdAt: -1 });
callSchema.index({ receiverIds: 1, createdAt: -1 });

callSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    callerId: this.callerId.toString(),
    receiverIds: this.receiverIds.map((r) => r.toString()),
    conversationId: this.conversationId ? this.conversationId.toString() : null,
    callType: this.callType,
    status: this.status,
    startedAt: this.startedAt,
    answeredAt: this.answeredAt,
    endedAt: this.endedAt,
    duration: this.duration,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('Call', callSchema);
