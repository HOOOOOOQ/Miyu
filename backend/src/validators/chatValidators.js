'use strict';

const { z } = require('zod');
const { objectId } = require('./userValidators');

const createChatSchema = z.object({
  participantId: objectId,
});

const messageTypeEnum = z.enum(['text', 'image', 'video', 'file', 'audio']);

const sendMessageSchema = z
  .object({
    conversationId: objectId,
    clientMessageId: z.string().max(80).optional(),
    messageType: messageTypeEnum.optional().default('text'),
    content: z.string().max(5000).optional().default(''),
    mediaUrl: z.string().url().nullable().optional(),
    mediaMeta: z
      .object({
        fileName: z.string().max(255).nullable().optional(),
        fileSize: z.number().nonnegative().nullable().optional(),
        mimeType: z.string().max(120).nullable().optional(),
        width: z.number().nullable().optional(),
        height: z.number().nullable().optional(),
        duration: z.number().nullable().optional(),
        thumbnailUrl: z.string().url().nullable().optional(),
      })
      .nullable()
      .optional(),
    replyTo: objectId.nullable().optional(),
    forwardedFrom: objectId.nullable().optional(),
  })
  .refine((v) => v.messageType !== 'text' || v.content.trim().length > 0, {
    message: 'Text messages require content',
    path: ['content'],
  })
  .refine((v) => v.messageType === 'text' || Boolean(v.mediaUrl), {
    message: 'Media messages require mediaUrl',
    path: ['mediaUrl'],
  });

const editMessageSchema = z.object({
  content: z.string().trim().min(1).max(5000),
});

const deleteMessageSchema = z.object({
  mode: z.enum(['me', 'everyone']).optional().default('everyone'),
});

const reactionSchema = z.object({
  emoji: z.union([z.string().min(1).max(8), z.null()]),
});

const readSchema = z.object({ conversationId: objectId });
const deliveredSchema = z.object({ conversationId: objectId });

module.exports = {
  createChatSchema,
  sendMessageSchema,
  editMessageSchema,
  deleteMessageSchema,
  reactionSchema,
  readSchema,
  deliveredSchema,
};
