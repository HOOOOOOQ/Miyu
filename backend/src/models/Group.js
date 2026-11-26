'use strict';

const mongoose = require('mongoose');

const groupSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    description: { type: String, default: '', maxlength: 300 },
    avatar: { type: String, default: null },
    members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }],
    admins: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }],
    owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    conversationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Conversation', default: null },
    memberPermissions: {
      sendMessages: { type: Boolean, default: true },
      addMembers: { type: Boolean, default: true },
      editGroupInfo: { type: Boolean, default: false },
    },
  },
  { timestamps: true, versionKey: false }
);

groupSchema.index({ members: 1 });
groupSchema.index({ name: 'text', description: 'text' });

groupSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    name: this.name,
    description: this.description,
    avatar: this.avatar,
    members: this.members.map((m) => m.toString()),
    admins: this.admins.map((a) => a.toString()),
    owner: this.owner.toString(),
    conversationId: this.conversationId ? this.conversationId.toString() : null,
    memberPermissions: this.memberPermissions,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('Group', groupSchema);
