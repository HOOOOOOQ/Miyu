'use strict';

/**
 * Central bridge so REST controllers can push realtime events without importing
 * the whole Socket.IO server (avoids circular dependencies).
 */
let ioRef = null;

function setIo(io) {
  ioRef = io;
}

function getIo() {
  return ioRef;
}

function userRoom(userId) {
  return `user:${String(userId)}`;
}

function conversationRoom(conversationId) {
  return `chat:${String(conversationId)}`;
}

function emitToUser(userId, event, payload) {
  if (!ioRef) return;
  ioRef.to(userRoom(userId)).emit(event, payload);
}

function emitToConversation(conversationId, event, payload, exceptSocketId = null) {
  if (!ioRef) return;
  let target = ioRef.to(conversationRoom(conversationId));
  if (exceptSocketId) target = target.except(exceptSocketId);
  target.emit(event, payload);
}

function emitToUsers(userIds, event, payload) {
  if (!ioRef) return;
  ioRef.to((userIds || []).map(userRoom)).emit(event, payload);
}

module.exports = {
  setIo,
  getIo,
  userRoom,
  conversationRoom,
  emitToUser,
  emitToConversation,
  emitToUsers,
};
