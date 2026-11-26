'use strict';

/**
 * End-to-end REST contract for the messaging surface: chats, messages,
 * reactions, receipts and groups. Runs against a real database (a CI service
 * container or mongodb-memory-server); skipped — visibly — when neither is
 * reachable.
 */
const request = require('supertest');
const mongo = require('./setup/mongo');

process.env.JWT_ACCESS_SECRET = 'test-access-secret-'.padEnd(32, 'a');
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-'.padEnd(32, 'b');
process.env.JWT_ACCESS_EXPIRES_IN = '15m';
process.env.JWT_REFRESH_EXPIRES_IN = '30d';
process.env.GOOGLE_CLIENT_ID = 'test-client.apps.googleusercontent.com';

const { createApp } = require('../src/app');
const { createUser, authFor, createDirectConversation } = require('./helpers/fixtures');

const describeDb = mongo.isConfigured ? describe : describe.skip;

describeDb('Chats, messages & groups (database)', () => {
  const app = createApp();
  let alice;
  let bob;
  let aliceAuth;
  let bobAuth;
  let chatId;

  beforeAll(async () => {
    await mongo.connect();
  });

  afterAll(async () => {
    await mongo.disconnect();
  });

  beforeEach(async () => {
    await mongo.clearDatabase();
    alice = await createUser({ displayName: 'Alice' });
    bob = await createUser({ displayName: 'Bob' });
    aliceAuth = await authFor(alice);
    bobAuth = await authFor(bob);
    const chat = await createDirectConversation(alice, bob);
    chatId = chat._id.toString();
  });

  it('lists a direct conversation for both participants', async () => {
    const res = await request(app).get('/api/chats').set('Authorization', aliceAuth.header);
    expect(res.status).toBe(200);
    const chats = res.body.data.chats;
    expect(chats).toHaveLength(1);
    expect(chats[0]).toMatchObject({
      id: chatId,
      conversationType: 'direct',
      peerId: bob._id.toString(),
    });
    expect(chats[0].participantProfiles).toHaveLength(2);
  });

  it('sends a message, dedupes on clientMessageId and paginates history', async () => {
    const send = await request(app)
      .post('/api/messages')
      .set('Authorization', aliceAuth.header)
      .send({ conversationId: chatId, content: 'Hello Bob', messageType: 'text', clientMessageId: 'client-1' });
    expect(send.status).toBe(201);
    const message = send.body.data.message;
    expect(message).toMatchObject({
      conversationId: chatId,
      senderId: alice._id.toString(),
      content: 'Hello Bob',
      messageType: 'text',
      clientMessageId: 'client-1',
    });

    // Same clientMessageId must not create a duplicate.
    const again = await request(app)
      .post('/api/messages')
      .set('Authorization', aliceAuth.header)
      .send({ conversationId: chatId, content: 'Hello Bob', messageType: 'text', clientMessageId: 'client-1' });
    expect([200, 201]).toContain(again.status);
    expect(again.body.data.message.id).toBe(message.id);

    await request(app)
      .post('/api/messages')
      .set('Authorization', aliceAuth.header)
      .send({ conversationId: chatId, content: 'Second', messageType: 'text' });

    const list = await request(app)
      .get(`/api/chats/${chatId}/messages?limit=1`)
      .set('Authorization', bobAuth.header);
    expect(list.status).toBe(200);
    expect(list.body.data.messages).toHaveLength(1);
    expect(list.body.data.messages[0].content).toBe('Second');
    expect(list.body.data.nextCursor).toBeTruthy();
  });

  it('refuses messages from non-participants', async () => {
    const stranger = await createUser({ displayName: 'Stranger' });
    const strangerAuth = await authFor(stranger);
    const res = await request(app)
      .post('/api/messages')
      .set('Authorization', strangerAuth.header)
      .send({ conversationId: chatId, content: 'let me in', messageType: 'text' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('NOT_A_PARTICIPANT');
  });

  it('edits, reacts to and soft-deletes a message', async () => {
    const send = await request(app)
      .post('/api/messages')
      .set('Authorization', aliceAuth.header)
      .send({ conversationId: chatId, content: 'typo', messageType: 'text' });
    const id = send.body.data.message.id;

    const edit = await request(app)
      .patch(`/api/messages/${id}`)
      .set('Authorization', aliceAuth.header)
      .send({ content: 'fixed' });
    expect(edit.status).toBe(200);
    expect(edit.body.data.message.content).toBe('fixed');
    expect(edit.body.data.message.editedAt).toBeTruthy();

    const react = await request(app)
      .post(`/api/messages/${id}/reactions`)
      .set('Authorization', bobAuth.header)
      .send({ emoji: '👍' });
    expect(react.status).toBe(200);
    expect(react.body.data.message.reactions).toEqual([
      { user: bob._id.toString(), emoji: '👍' },
    ]);

    const remove = await request(app)
      .delete(`/api/messages/${id}`)
      .set('Authorization', aliceAuth.header)
      .send({ mode: 'everyone' });
    expect(remove.status).toBe(200);

    const list = await request(app)
      .get(`/api/chats/${chatId}/messages`)
      .set('Authorization', bobAuth.header);
    const deleted = list.body.data.messages.find((m) => m.id === id);
    expect(deleted.isDeleted).toBe(true);
    expect(deleted.content).toBe('');
  });

  it('prevents a non-sender from editing or deleting another user’s message', async () => {
    const send = await request(app)
      .post('/api/messages')
      .set('Authorization', aliceAuth.header)
      .send({ conversationId: chatId, content: 'mine', messageType: 'text' });
    const id = send.body.data.message.id;

    const edit = await request(app)
      .patch(`/api/messages/${id}`)
      .set('Authorization', bobAuth.header)
      .send({ content: 'hijacked' });
    expect(edit.status).toBe(403);

    const del = await request(app)
      .delete(`/api/messages/${id}`)
      .set('Authorization', bobAuth.header)
      .send({ mode: 'everyone' });
    expect(del.status).toBe(403);
  });

  it('marks messages delivered and read, and resets the unread badge', async () => {
    const send = await request(app)
      .post('/api/messages')
      .set('Authorization', aliceAuth.header)
      .send({ conversationId: chatId, content: 'ping', messageType: 'text' });
    const id = send.body.data.message.id;

    const before = await request(app).get('/api/chats').set('Authorization', bobAuth.header);
    expect(before.body.data.chats[0].unreadCount).toBe(1);

    const delivered = await request(app)
      .post(`/api/chats/${chatId}/delivered`)
      .set('Authorization', bobAuth.header);
    expect(delivered.status).toBe(200);

    const read = await request(app)
      .post(`/api/chats/${chatId}/read`)
      .set('Authorization', bobAuth.header);
    expect(read.status).toBe(200);

    const list = await request(app)
      .get(`/api/chats/${chatId}/messages`)
      .set('Authorization', aliceAuth.header);
    const message = list.body.data.messages.find((m) => m.id === id);
    expect(message.deliveredTo).toContain(bob._id.toString());
    expect(message.readBy).toContain(bob._id.toString());

    const after = await request(app).get('/api/chats').set('Authorization', bobAuth.header);
    expect(after.body.data.chats[0].unreadCount).toBe(0);
  });

  it('creates a group, promotes an admin and enforces admin-only updates', async () => {
    const carol = await createUser({ displayName: 'Carol' });
    const carolAuth = await authFor(carol);

    const created = await request(app)
      .post('/api/groups')
      .set('Authorization', aliceAuth.header)
      .send({ name: 'Design crew', memberIds: [bob._id.toString(), carol._id.toString()] });
    expect(created.status).toBe(201);
    const group = created.body.data.group;
    expect(group.name).toBe('Design crew');
    expect(group.members).toHaveLength(3);
    expect(group.admins).toContain(alice._id.toString());
    expect(group.conversationId).toBeTruthy();

    const promote = await request(app)
      .post(`/api/groups/${group.id}/admins`)
      .set('Authorization', aliceAuth.header)
      .send({ userId: bob._id.toString(), makeAdmin: true });
    expect(promote.status).toBe(200);
    expect(promote.body.data.group.admins).toContain(bob._id.toString());

    // Carol is a plain member and may not rename the group.
    const denied = await request(app)
      .patch(`/api/groups/${group.id}`)
      .set('Authorization', carolAuth.header)
      .send({ name: 'Hijacked' });
    expect(denied.status).toBe(403);

    // The promoted admin can.
    const renamed = await request(app)
      .patch(`/api/groups/${group.id}`)
      .set('Authorization', bobAuth.header)
      .send({ name: 'Design crew 2' });
    expect(renamed.status).toBe(200);
    expect(renamed.body.data.group.name).toBe('Design crew 2');

    const groupChat = await request(app)
      .get(`/api/chats/${group.conversationId}`)
      .set('Authorization', carolAuth.header);
    expect(groupChat.status).toBe(200);
    expect(groupChat.body.data.chat.conversationType).toBe('group');
    expect(groupChat.body.data.chat.group.name).toBe('Design crew 2');
  });

  it('removes a member and blocks them from the group conversation', async () => {
    const carol = await createUser({ displayName: 'Carol' });
    const carolAuth = await authFor(carol);
    const created = await request(app)
      .post('/api/groups')
      .set('Authorization', aliceAuth.header)
      .send({ name: 'Temp', memberIds: [bob._id.toString(), carol._id.toString()] });
    const group = created.body.data.group;

    const removed = await request(app)
      .delete(`/api/groups/${group.id}/members/${carol._id.toString()}`)
      .set('Authorization', aliceAuth.header);
    expect(removed.status).toBe(200);

    const denied = await request(app)
      .post('/api/messages')
      .set('Authorization', carolAuth.header)
      .send({ conversationId: group.conversationId, content: 'still here?', messageType: 'text' });
    // Removed members lose access; the API answers 404 rather than leaking the
    // conversation's existence.
    expect([403, 404]).toContain(denied.status);
    expect(denied.body.success).toBe(false);
  });
});
