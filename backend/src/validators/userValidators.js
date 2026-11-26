'use strict';

const { z } = require('zod');

const objectId = z.string().regex(/^[a-f\d]{24}$/i, 'Invalid id');

const updateMeSchema = z
  .object({
    displayName: z.string().trim().min(1).max(60).optional(),
    username: z
      .string()
      .trim()
      .toLowerCase()
      .min(3)
      .max(30)
      .regex(/^[a-z0-9_.]+$/, 'Username may only contain a-z, 0-9, underscore and dot')
      .optional(),
    bio: z.string().max(200).optional(),
    photoURL: z.string().url().nullable().optional(),
    showOnlineStatus: z.boolean().optional(),
    showLastSeen: z.boolean().optional(),
    notificationsEnabled: z.boolean().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'At least one field is required' });

const searchQuerySchema = z.object({
  q: z.string().trim().min(1).max(60),
  limit: z.coerce.number().int().min(1).max(50).optional(),
});

const blockSchema = z.object({
  reason: z.string().max(300).optional(),
});

const reportSchema = z.object({
  reason: z.string().trim().min(3).max(500),
});

const registerDeviceSchema = z.object({
  fcmToken: z.string().min(10),
  platform: z.enum(['android', 'ios', 'web']).optional(),
  deviceName: z.string().max(120).optional(),
});

const unregisterDeviceSchema = z.object({
  fcmToken: z.string().min(10),
});

module.exports = {
  updateMeSchema,
  searchQuerySchema,
  blockSchema,
  reportSchema,
  registerDeviceSchema,
  unregisterDeviceSchema,
  objectId,
};
