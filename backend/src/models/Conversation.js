'use strict';

const mongoose = require('mongoose');

const conversationSchema = new mongoose.Schema(
  {
    participants: [
      { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    ],
    conversationType: {
      type: String,
      enum: ['direct', 'group'],
      default: 'direct',
      index: true,
    },
    group: { type: mongoose.Schema.Types.ObjectId, ref: 'Group', default: null },
    lastMessage: { type: mongoose.Schema.Types.ObjectId, ref: 'Message', default: null },
    lastActivity: { type: Date, default: Date.now, index: true },
    unreadCounts: {
      type: Map,
      of: Number,
      default: () => new Map(),
    },
    pinnedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    archivedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    mutedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true, versionKey: false }
);

// One direct conversation per participant pair (lookup helper index)
conversationSchema.index({ participants: 1, lastActivity: -1 });
conversationSchema.index({ conversationType: 1, group: 1 });

conversationSchema.methods.unreadFor = function unreadFor(userId) {
  if (!this.unreadCounts) return 0;
  const raw = this.unreadCounts.get(String(userId));
  return typeof raw === 'number' ? raw : 0;
};

module.exports = mongoose.model('Conversation', conversationSchema);
