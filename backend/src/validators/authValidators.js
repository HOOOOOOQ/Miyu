'use strict';

const { z } = require('zod');

const googleLoginSchema = z.object({
  idToken: z.string().min(20, 'A valid Google ID token is required'),
  deviceName: z.string().max(120).optional(),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(10),
});

const logoutSchema = z.object({
  refreshToken: z.string().min(10).optional(),
  fcmToken: z.string().optional(),
});

module.exports = { googleLoginSchema, refreshSchema, logoutSchema };
