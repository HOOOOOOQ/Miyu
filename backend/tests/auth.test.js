'use strict';

const request = require('supertest');
const mongo = require('./setup/mongo');

// Force env before app modules resolve config.
process.env.JWT_ACCESS_SECRET = 'test-access-secret-'.padEnd(32, 'a');
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-'.padEnd(32, 'b');
process.env.JWT_REFRESH_EXPIRES_IN = '30d';
process.env.GOOGLE_CLIENT_ID = 'test-client.apps.googleusercontent.com';

const { createApp } = require('../src/app');
const { createUser, authFor } = require('./helpers/fixtures');
const { User, RefreshToken } = require('../src/models');
const { verifyAccessToken } = require('../src/utils/tokens');

// Honest reporting: the DB block is skipped (not silently passed) when no
// MongoDB is reachable. Set MONGODB_URI_TEST in CI to run it for real.
const describeDb = mongo.isConfigured ? describe : describe.skip;

describeDb('Authentication & token lifecycle (database)', () => {
  const app = createApp();

  beforeAll(async () => {
    await mongo.connect();
  });
  afterEach(async () => {
    await mongo.clearDatabase();
  });
  afterAll(async () => {
    await mongo.disconnect();
  });

  const dbIt = it;

  dbIt('issues an access token whose claims carry the user id', async () => {
    const user = await createUser();
    const auth = await authFor(user);
    const payload = verifyAccessToken(auth.accessToken);
    expect(payload.sub).toBe(user._id.toString());
    expect(payload.type).toBe('access');
  });

  dbIt('rejects refresh with an invalid token', async () => {
    const res = await request(app).post('/api/auth/refresh').send({ refreshToken: 'garbage-token-value' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_REFRESH_TOKEN');
  });

  dbIt('rotates refresh tokens and revokes the presented one', async () => {
    const user = await createUser();
    const auth = await authFor(user);
    const res = await request(app).post('/api/auth/refresh').send({ refreshToken: auth.refreshToken });
    expect(res.status).toBe(200);
    expect(res.body.data.accessToken).toBeTruthy();
    expect(res.body.data.refreshToken).not.toBe(auth.refreshToken);

    // Old token must now be unusable.
    const reuse = await request(app).post('/api/auth/refresh').send({ refreshToken: auth.refreshToken });
    expect(reuse.status).toBe(401);
    expect(['REFRESH_TOKEN_REVOKED', 'REFRESH_TOKEN_REUSE', 'INVALID_REFRESH_TOKEN']).toContain(
      reuse.body.error.code
    );
  });

  dbIt('detects refresh-token reuse and revokes the whole family', async () => {
    const user = await createUser();
    const auth = await authFor(user);
    const first = await request(app).post('/api/auth/refresh').send({ refreshToken: auth.refreshToken });
    const secondToken = first.body.data.refreshToken;

    // Replay the original (already rotated) token → family killed.
    const replay = await request(app).post('/api/auth/refresh').send({ refreshToken: auth.refreshToken });
    expect(replay.status).toBe(401);

    // The descendant must also be dead now.
    const descendant = await request(app).post('/api/auth/refresh').send({ refreshToken: secondToken });
    expect(descendant.status).toBe(401);

    const live = await RefreshToken.countDocuments({ user: user._id, revokedAt: null });
    expect(live).toBe(0);
  });

  dbIt('logs out by revoking the refresh token', async () => {
    const user = await createUser();
    const auth = await authFor(user);
    const res = await request(app)
      .post('/api/auth/logout')
      .set('Authorization', auth.header)
      .send({ refreshToken: auth.refreshToken });
    expect(res.status).toBe(200);
    expect(res.body.data.loggedOut).toBe(true);

    const stored = await RefreshToken.findOne({ user: user._id });
    expect(stored.revokedAt).not.toBeNull();

    const refreshed = await User.findById(user._id);
    expect(refreshed.isOnline).toBe(false);
  });

});

// This path only needs Google's verifier to reject a malformed token, so it
// runs with or without a database.
describe('Authentication & token lifecycle (no database)', () => {
  const app = createApp();

  it('rejects Google login when the ID token cannot be verified', async () => {
    const res = await request(app)
      .post('/api/auth/google')
      .send({ idToken: 'eyJhbGciOiJSUzI1NiJ9.invalid.invalid' });
    expect([401, 500]).toContain(res.status);
    expect(res.body.success).toBe(false);
  });
});
