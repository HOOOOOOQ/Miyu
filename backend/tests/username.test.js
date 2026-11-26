'use strict';

process.env.NODE_ENV = 'test';

const { sanitizeUsernameSeed, RESERVED } = require('../src/utils/username');

describe('Username generation helpers', () => {
  it('sanitizes emails and names into valid usernames', () => {
    expect(sanitizeUsernameSeed('john.doe')).toBe('john.doe');
    expect(sanitizeUsernameSeed('María José')).toBe('marajos');
    expect(sanitizeUsernameSeed('--weird__name--')).toBe('weird__name');
  });

  it('pads short seeds to the minimum length', () => {
    const result = sanitizeUsernameSeed('ab');
    expect(result.length).toBeGreaterThanOrEqual(3);
    expect(result).toMatch(/^[a-z0-9_.]+$/);
  });

  it('caps long seeds at 22 characters', () => {
    const result = sanitizeUsernameSeed('a'.repeat(80));
    expect(result.length).toBeLessThanOrEqual(22);
  });

  it('handles empty and null input', () => {
    expect(sanitizeUsernameSeed(null)).toBe('miyu');
    expect(sanitizeUsernameSeed('')).toBe('miyu');
  });

  it('maintains a reserved-name list', () => {
    expect(RESERVED.has('admin')).toBe(true);
    expect(RESERVED.has('miyu')).toBe(true);
  });
});
