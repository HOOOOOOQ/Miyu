'use strict';

const { z } = require('zod');
const { objectId } = require('./userValidators');

const createCallSchema = z.object({
  receiverIds: z.array(objectId).min(1).max(1),
  callType: z.enum(['voice', 'video']),
  conversationId: objectId.nullable().optional(),
});

const callActionSchema = z.object({
  callId: objectId,
});

const endCallSchema = z.object({
  callId: objectId,
  status: z.enum(['ended', 'missed', 'rejected', 'cancelled', 'busy', 'failed']).optional(),
});

module.exports = { createCallSchema, callActionSchema, endCallSchema };
