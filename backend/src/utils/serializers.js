'use strict';

const User = require('../models/User');

/** Converts a lean/plain message doc (with populated sender) into API shape. */
function messageToPublic(message, senderOverride = null) {
  if (!message) return null;
  const isDoc = typeof message.toPublic === 'function';
  const base = isDoc ? message.toPublic() : plainMessageToPublic(message);
  const senderDoc = senderOverride || (message.senderId && message.senderId.displayName ? message.senderId : null);
  if (senderDoc && senderDoc.displayName) {
    base.sender = senderDoc instanceof User || typeof senderDoc.toPublic === 'function'
      ? senderDoc.toPublic()
      : {
          id: senderDoc._id.toString(),
          displayName: senderDoc.displayName,
          username: senderDoc.username,
          photoURL: senderDoc.photoURL || null,
        };
    base.senderId = senderDoc._id.toString();
  }
  return base;
}

function plainMessageToPublic(m) {
  return {
    id: m._id.toString(),
    conversationId: m.conversationId.toString(),
    senderId: m.senderId && m.senderId._id ? m.senderId._id.toString() : String(m.senderId),
    clientMessageId: m.clientMessageId || null,
    messageType: m.messageType,
    content: m.deletedAt ? '' : m.content,
    mediaUrl: m.deletedAt ? null : m.mediaUrl,
    mediaMeta: m.deletedAt ? null : m.mediaMeta,
    replyTo: m.replyTo ? (m.replyTo._id ? m.replyTo._id.toString() : m.replyTo.toString()) : null,
    replyToPreview: m.replyTo && m.replyTo._id ? plainMessageToPublic(m.replyTo) : null,
    forwardedFrom: m.forwardedFrom ? String(m.forwardedFrom) : null,
    reactions: (m.reactions || []).map((r) => ({
      user: r.user._id ? r.user._id.toString() : String(r.user),
      emoji: r.emoji,
    })),
    deliveredTo: (m.deliveredTo || []).map((u) => (u._id ? u._id.toString() : String(u))),
    readBy: (m.readBy || []).map((u) => (u._id ? u._id.toString() : String(u))),
    deliveredAt: m.deliveredAt || null,
    readAt: m.readAt || null,
    editedAt: m.editedAt || null,
    isDeleted: Boolean(m.deletedAt),
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
  };
}

/** Shapes a conversation for a specific viewer, resolving the direct-chat peer. */
function conversationToPublic(conversation, viewerId, { lastMessage = null, group = null, participants = [] } = {}) {
  const c = conversation.toObject ? conversation.toObject() : conversation;
  const participantIds = (c.participants || []).map((p) => (p._id ? p._id.toString() : String(p)));
  const peer = participantIds.find((id) => id !== String(viewerId));
  const unreadCounts = c.unreadCounts instanceof Map ? Object.fromEntries(c.unreadCounts) : c.unreadCounts || {};
  const meta = c.group && typeof c.group === 'object' && c.group.name ? c.group : group;
  return {
    id: c._id.toString(),
    conversationType: c.conversationType,
    participants: participantIds,
    participantProfiles: participants,
    peerId: c.conversationType === 'direct' ? peer || null : null,
    group: meta
      ? typeof meta.toPublic === 'function'
        ? meta.toPublic()
        : meta
      : null,
    lastMessage: lastMessage ? (typeof lastMessage.toPublic === 'function' ? lastMessage.toPublic() : lastMessage) : null,
    lastActivity: c.lastActivity,
    unreadCount: Number(unreadCounts[String(viewerId)] || 0),
    pinned: (c.pinnedBy || []).map((p) => (p._id ? p._id.toString() : String(p))).includes(String(viewerId)),
    archived: (c.archivedBy || []).map((p) => (p._id ? p._id.toString() : String(p))).includes(String(viewerId)),
    muted: (c.mutedBy || []).map((p) => (p._id ? p._id.toString() : String(p))).includes(String(viewerId)),
    createdAt: c.createdAt,
  };
}

module.exports = { messageToPublic, plainMessageToPublic, conversationToPublic };
