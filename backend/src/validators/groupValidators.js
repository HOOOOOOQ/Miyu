'use strict';

const { z } = require('zod');
const { objectId } = require('./userValidators');

const createGroupSchema = z.object({
  name: z.string().trim().min(1).max(80),
  description: z.string().max(300).optional().default(''),
  avatar: z.string().url().nullable().optional(),
  memberIds: z.array(objectId).min(1).max(200),
});

const updateGroupSchema = z
  .object({
    name: z.string().trim().min(1).max(80).optional(),
    description: z.string().max(300).optional(),
    avatar: z.string().url().nullable().optional(),
    memberPermissions: z
      .object({
        sendMessages: z.boolean().optional(),
        addMembers: z.boolean().optional(),
        editGroupInfo: z.boolean().optional(),
      })
      .optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'At least one field is required' });

const addMembersSchema = z.object({
  memberIds: z.array(objectId).min(1).max(100),
});

const setAdminSchema = z.object({
  userId: objectId,
  makeAdmin: z.boolean().optional().default(true),
});

module.exports = { createGroupSchema, updateGroupSchema, addMembersSchema, setAdminSchema };
