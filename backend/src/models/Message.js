'use strict';

const mongoose = require('mongoose');

const reactionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    emoji: { type: String, required: true, maxlength: 8 },
  },
  { _id: false, timestamps: true }
);

const messageSchema = new mongoose.Schema(
  {
    conversationId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Conversation',
      required: true,
      index: true,
    },
    senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    clientMessageId: { type: String, default: null },
    messageType: {
      type: String,
      enum: ['text', 'image', 'video', 'file', 'audio', 'system'],
      default: 'text',
      index: true,
    },
    content: { type: String, default: '', maxlength: 5000 },
    mediaUrl: { type: String, default: null },
    mediaMeta: {
      fileName: { type: String, default: null },
      fileSize: { type: Number, default: null },
      mimeType: { type: String, default: null },
      width: { type: Number, default: null },
      height: { type: Number, default: null },
      duration: { type: Number, default: null },
      thumbnailUrl: { type: String, default: null },
    },
    replyTo: { type: mongoose.Schema.Types.ObjectId, ref: 'Message', default: null },
    forwardedFrom: { type: mongoose.Schema.Types.ObjectId, ref: 'Message', default: null },
    reactions: { type: [reactionSchema], default: [] },
    deliveredTo: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    readBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    deliveredAt: { type: Date, default: null },
    readAt: { type: Date, default: null },
    editedAt: { type: Date, default: null },
    deletedAt: { type: Date, default: null },
    deletedFor: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  },
  { timestamps: true, versionKey: false }
);

messageSchema.index({ conversationId: 1, createdAt: -1 });
// Duplicate protection for retried sends from the same client.
messageSchema.index(
  { senderId: 1, clientMessageId: 1 },
  { unique: true, partialFilterExpression: { clientMessageId: { $type: 'string' } } }
);
messageSchema.index({ conversationId: 1, readBy: 1 });

messageSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    conversationId: this.conversationId.toString(),
    senderId: this.senderId.toString(),
    clientMessageId: this.clientMessageId,
    messageType: this.messageType,
    content: this.deletedAt ? '' : this.content,
    mediaUrl: this.deletedAt ? null : this.mediaUrl,
    mediaMeta: this.deletedAt ? null : this.mediaMeta,
    replyTo: this.replyTo ? this.replyTo.toString() : null,
    forwardedFrom: this.forwardedFrom ? this.forwardedFrom.toString() : null,
    reactions: (this.reactions || []).map((r) => ({
      user: r.user.toString(),
      emoji: r.emoji,
    })),
    deliveredTo: (this.deliveredTo || []).map((u) => u.toString()),
    readBy: (this.readBy || []).map((u) => u.toString()),
    deliveredAt: this.deliveredAt,
    readAt: this.readAt,
    editedAt: this.editedAt,
    isDeleted: Boolean(this.deletedAt),
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

module.exports = mongoose.model('Message', messageSchema);
