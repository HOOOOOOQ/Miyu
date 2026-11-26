'use strict';

process.env.NODE_ENV = 'test';

const {
  sendMessageSchema,
  createChatSchema,
  deleteMessageSchema,
  reactionSchema,
} = require('../src/validators/chatValidators');
const { createGroupSchema } = require('../src/validators/groupValidators');
const { createCallSchema } = require('../src/validators/callValidators');
const { updateMeSchema } = require('../src/validators/userValidators');

const oid = '507f1f77bcf86cd799439011';

describe('Zod request validation', () => {
  it('accepts a valid text message', () => {
    const result = sendMessageSchema.safeParse({
      conversationId: oid,
      messageType: 'text',
      content: 'hello there',
    });
    expect(result.success).toBe(true);
  });

  it('rejects an empty text message', () => {
    const result = sendMessageSchema.safeParse({
      conversationId: oid,
      messageType: 'text',
      content: '   ',
    });
    expect(result.success).toBe(false);
  });

  it('requires mediaUrl for media messages', () => {
    const bad = sendMessageSchema.safeParse({
      conversationId: oid,
      messageType: 'image',
      mediaUrl: null,
    });
    expect(bad.success).toBe(false);

    const good = sendMessageSchema.safeParse({
      conversationId: oid,
      messageType: 'image',
      mediaUrl: 'https://res.cloudinary.com/demo/image/upload/x.jpg',
    });
    expect(good.success).toBe(true);
  });

  it('rejects malformed object ids', () => {
    expect(createChatSchema.safeParse({ participantId: 'nope' }).success).toBe(false);
    expect(createChatSchema.safeParse({ participantId: oid }).success).toBe(true);
  });

  it('defaults delete mode to everyone and only allows me/everyone', () => {
    expect(deleteMessageSchema.parse({}).mode).toBe('everyone');
    expect(deleteMessageSchema.safeParse({ mode: 'everyone' }).success).toBe(true);
    expect(deleteMessageSchema.safeParse({ mode: 'nobody' }).success).toBe(false);
  });

  it('allows null emoji to clear a reaction', () => {
    expect(reactionSchema.safeParse({ emoji: null }).success).toBe(true);
    expect(reactionSchema.safeParse({ emoji: '👍' }).success).toBe(true);
    expect(reactionSchema.safeParse({ emoji: 'x'.repeat(20) }).success).toBe(false);
  });

  it('validates group creation requires at least one member', () => {
    expect(createGroupSchema.safeParse({ name: 'Squad', memberIds: [] }).success).toBe(false);
    expect(createGroupSchema.safeParse({ name: 'Squad', memberIds: [oid] }).success).toBe(true);
  });

  it('validates call creation payloads', () => {
    expect(
      createCallSchema.safeParse({ receiverIds: [oid], callType: 'video' }).success
    ).toBe(true);
    expect(
      createCallSchema.safeParse({ receiverIds: [oid], callType: 'telepathy' }).success
    ).toBe(false);
  });

  it('validates profile updates', () => {
    expect(updateMeSchema.safeParse({ displayName: 'Miyu User' }).success).toBe(true);
    expect(updateMeSchema.safeParse({ username: 'bad username!' }).success).toBe(false);
    expect(updateMeSchema.safeParse({}).success).toBe(false);
  });
});
