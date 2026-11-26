'use strict';

process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = 'unit-access-secret-'.padEnd(40, 'x');
process.env.JWT_REFRESH_SECRET = 'unit-refresh-secret-'.padEnd(40, 'y');
process.env.JWT_ACCESS_EXPIRES_IN = '15m';
process.env.JWT_REFRESH_EXPIRES_IN = '30d';

const jwt = require('jsonwebtoken');
const {
  signAccessToken,
  signRefreshTokenValue,
  verifyAccessToken,
  verifyRefreshToken,
  hashToken,
  durationToMs,
  newTokenFamily,
} = require('../src/utils/tokens');

const fakeUser = { _id: '507f1f77bcf86cd799439011', username: 'miyu_tester' };

describe('JWT token utilities', () => {
  it('signs and verifies access tokens', () => {
    const token = signAccessToken(fakeUser);
    const payload = verifyAccessToken(token);
    expect(payload.sub).toBe(fakeUser._id);
    expect(payload.type).toBe('access');
  });

  it('rejects an access token presented where a refresh token is expected', () => {
    // Different secrets mean cross-use fails at signature verification.
    const token = signAccessToken(fakeUser);
    expect(() => verifyRefreshToken(token)).toThrow(/invalid signature/);
  });

  it('rejects refresh tokens on access verification', () => {
    const token = signRefreshTokenValue(fakeUser, newTokenFamily());
    expect(() => verifyAccessToken(token)).toThrow(/invalid signature/);
  });

  it('rejects tokens whose type claim is wrong even with the right secret', () => {
    const wrongType = jwt.sign(
      { sub: fakeUser._id, type: 'refresh' },
      process.env.JWT_ACCESS_SECRET,
      { issuer: 'miyu' }
    );
    expect(() => verifyAccessToken(wrongType)).toThrow(/token type/);
  });

  it('rejects tampered tokens', () => {
    const token = signAccessToken(fakeUser);
    const tampered = `${token.slice(0, -3)}abc`;
    expect(() => verifyAccessToken(tampered)).toThrow();
  });

  it('rejects tokens signed with the wrong secret', () => {
    const forged = jwt.sign({ sub: fakeUser._id, type: 'access' }, 'attacker-secret', {
      issuer: 'miyu',
    });
    expect(() => verifyAccessToken(forged)).toThrow();
  });

  it('rejects expired access tokens', () => {
    const expired = jwt.sign(
      { sub: fakeUser._id, type: 'access' },
      process.env.JWT_ACCESS_SECRET,
      { expiresIn: -10, issuer: 'miyu' }
    );
    expect(() => verifyAccessToken(expired)).toThrow(/expired/);
  });

  it('hashes tokens deterministically and irreversibly', () => {
    const a = hashToken('some-token');
    const b = hashToken('some-token');
    expect(a).toBe(b);
    expect(a).not.toContain('some-token');
    expect(hashToken('other-token')).not.toBe(a);
    expect(a).toHaveLength(64);
  });

  it('parses expiry durations', () => {
    expect(durationToMs('30d', 1)).toBe(30 * 86400000);
    expect(durationToMs('15m', 1)).toBe(15 * 60000);
    expect(durationToMs('45s', 1)).toBe(45000);
    expect(durationToMs('nonsense', 1234)).toBe(1234);
  });
});
