'use strict';

const { admin, initFirebase, isInitialized } = require('../config/firebase');
const { Device, User } = require('../models');
const logger = require('../config/logger');

function channelFor(type) {
  switch (type) {
    case 'incoming_call':
    case 'missed_call':
      return 'miyu_calls';
    case 'message':
    case 'group_message':
      return 'miyu_messages';
    default:
      return 'miyu_general';
  }
}

/**
 * Sends an FCM push to every registered device for a user.
 * Silently no-ops when Firebase is not configured or tokens fail.
 */
async function sendToUser(userId, { title, body, data = {}, type = 'message', highPriority = false }) {
  if (!isInitialized()) {
    initFirebase();
    if (!isInitialized()) return { sent: 0, skipped: true };
  }
  try {
    const devices = await Device.find({ user: userId }).lean();
    const user = await User.findById(userId).select('fcmTokens notificationsEnabled').lean();
    const tokens = new Set([
      ...devices.map((d) => d.fcmToken),
      ...(((user && user.fcmTokens) || [])),
    ]);
    if (tokens.size === 0) return { sent: 0, skipped: true };
    if (user && user.notificationsEnabled === false) return { sent: 0, skipped: true };

    const stringData = Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, v === null || v === undefined ? '' : String(v)])
    );
    const isCall = type === 'incoming_call' || type === 'missed_call';
    const response = await admin.messaging().sendEachForMulticast({
      tokens: [...tokens],
      notification: { title, body },
      data: { ...stringData, type },
      android: {
        priority: highPriority || isCall ? 'high' : 'normal',
        notification: {
          channelId: channelFor(type),
          priority: isCall ? 'max' : 'high',
          tag: data.conversationId || undefined,
        },
      },
      apns: isCall
        ? {
            headers: { 'apns-priority': '10' },
            payload: { aps: { sound: 'default', 'content-available': 1 } },
          }
        : undefined,
    });

    // Prune dead tokens.
    const stale = [];
    response.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error && r.error.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          stale.push([...tokens][i]);
        }
      }
    });
    if (stale.length) {
      await Device.deleteMany({ fcmToken: { $in: stale } });
      await User.updateMany({ _id: userId }, { $pull: { fcmTokens: { $in: stale } } });
    }
    return { sent: response.successCount, failed: response.failureCount };
  } catch (err) {
    logger.error({ err: err.message }, '[fcm] send failed');
    return { sent: 0, error: err.message };
  }
}

async function registerDevice({ userId, fcmToken, platform, deviceName }) {
  if (!fcmToken) return null;
  const device = await Device.findOneAndUpdate(
    { fcmToken },
    { $set: { user: userId, platform: platform || 'android', deviceName: deviceName || null, lastActiveAt: new Date() } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  await User.updateOne({ _id: userId }, { $addToSet: { fcmTokens: fcmToken } });
  return device;
}

async function unregisterDevice({ userId, fcmToken }) {
  if (!fcmToken) return;
  await Device.deleteOne({ fcmToken, user: userId });
  await User.updateOne({ _id: userId }, { $pull: { fcmTokens: fcmToken } });
}

async function unregisterAllDevices(userId) {
  await Device.deleteMany({ user: userId });
  await User.updateOne({ _id: userId }, { $set: { fcmTokens: [] } });
}

module.exports = { sendToUser, registerDevice, unregisterDevice, unregisterAllDevices };
