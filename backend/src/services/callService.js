'use strict';

const { Call, User } = require('../models');
const ApiError = require('../utils/ApiError');
const { toObjectId, isBlockedBetween } = require('./chatService');

const ACTIVE_STATUSES = ['ringing', 'ongoing', 'answered'];

async function createCall({ callerId, receiverIds, callType, conversationId = null }) {
  if (!['voice', 'video'].includes(callType)) {
    throw ApiError.badRequest('callType must be voice or video', 'INVALID_CALL_TYPE');
  }
  const receivers = (receiverIds || []).map(String).filter((id) => id !== String(callerId));
  if (receivers.length === 0) {
    throw ApiError.badRequest('At least one receiver is required', 'MISSING_RECEIVER');
  }
  if (receivers.length > 1) {
    throw ApiError.badRequest('Group calls are not supported yet', 'GROUP_CALL_UNSUPPORTED');
  }
  const receiver = await User.findById(receivers[0]).select('_id displayName username photoURL');
  if (!receiver) throw ApiError.notFound('Receiver not found', 'USER_NOT_FOUND');
  if (await isBlockedBetween(callerId, receivers[0])) {
    throw ApiError.forbidden('You cannot call this user', 'USER_BLOCKED');
  }
  // One active call per caller at a time; clean up stale ringing calls (>90s).
  const stale = await Call.find({
    $or: [{ callerId }, { receiverIds: callerId }],
    status: { $in: ACTIVE_STATUSES },
  });
  for (const call of stale) {
    const ageMs = Date.now() - new Date(call.startedAt).getTime();
    if (ageMs > 90_000) {
      call.status = 'ended';
      call.endedAt = new Date();
      await call.save();
    } else {
      throw ApiError.conflict('You are already in a call', 'CALL_IN_PROGRESS');
    }
  }

  const call = await Call.create({
    callerId,
    receiverIds: receivers,
    conversationId: conversationId || null,
    callType,
    status: 'ringing',
    startedAt: new Date(),
  });
  return { call, receiver };
}

async function getCallForUser(callId, userId) {
  if (!callId) throw ApiError.badRequest('callId is required', 'MISSING_CALL_ID');
  const call = await Call.findById(callId);
  if (!call) throw ApiError.notFound('Call not found', 'CALL_NOT_FOUND');
  const involved =
    String(call.callerId) === String(userId) ||
    call.receiverIds.some((r) => String(r) === String(userId));
  if (!involved) throw ApiError.forbidden('You are not part of this call', 'NOT_IN_CALL');
  return call;
}

async function acceptCall({ callId, userId }) {
  const call = await getCallForUser(callId, userId);
  if (!call.receiverIds.some((r) => String(r) === String(userId))) {
    throw ApiError.forbidden('Only the receiver can accept a call', 'NOT_RECEIVER');
  }
  if (call.status === 'ongoing' || call.status === 'answered') return call;
  if (call.status !== 'ringing') {
    throw ApiError.badRequest(`Call cannot be accepted from status ${call.status}`, 'INVALID_CALL_STATE');
  }
  call.status = 'ongoing';
  call.answeredAt = new Date();
  await call.save();
  return call;
}

async function endCall({ callId, userId, status }) {
  const call = await getCallForUser(callId, userId);
  if (['ended', 'missed', 'rejected', 'cancelled', 'busy', 'failed'].includes(call.status)) {
    return call;
  }
  const endedAt = new Date();
  const finalStatus =
    status ||
    (call.answeredAt ? 'ended' : String(call.callerId) === String(userId) ? 'cancelled' : 'rejected');
  if (!['ended', 'missed', 'rejected', 'cancelled', 'busy', 'failed'].includes(finalStatus)) {
    throw ApiError.badRequest('Invalid final call status', 'INVALID_CALL_STATE');
  }
  call.status = finalStatus;
  call.endedAt = endedAt;
  call.endedBy = userId;
  call.duration = call.answeredAt
    ? Math.max(0, Math.round((endedAt.getTime() - new Date(call.answeredAt).getTime()) / 1000))
    : 0;
  await call.save();
  return call;
}

async function expireStaleCalls() {
  const cutoff = new Date(Date.now() - 60_000);
  await Call.updateMany(
    { status: 'ringing', startedAt: { $lt: cutoff } },
    { $set: { status: 'missed', endedAt: new Date() } }
  );
}

async function callHistory({ userId, limit = 50, cursor = null }) {
  const filter = { $or: [{ callerId: userId }, { receiverIds: userId }] };
  if (cursor) {
    const { decodeCursor } = require('../utils/pagination');
    const decoded = decodeCursor(cursor);
    if (decoded) filter.createdAt = { $lt: decoded.createdAt };
  }
  return Call.find(filter)
    .sort({ createdAt: -1 })
    .limit(Math.min(Number(limit) || 50, 100))
    .populate('callerId', 'displayName username photoURL')
    .populate('receiverIds', 'displayName username photoURL');
}

async function activeCallFor(userId) {
  return Call.findOne({
    $or: [{ callerId: userId }, { receiverIds: userId }],
    status: { $in: ACTIVE_STATUSES },
  }).sort({ createdAt: -1 });
}

module.exports = {
  createCall,
  getCallForUser,
  acceptCall,
  endCall,
  callHistory,
  activeCallFor,
  expireStaleCalls,
  toObjectId,
  ACTIVE_STATUSES,
};
