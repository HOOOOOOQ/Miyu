'use strict';

function parsePagination(query, { defaultLimit = 30, maxLimit = 100 } = {}) {
  const limitRaw = Number(query.limit);
  const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, maxLimit) : defaultLimit;
  const cursor = typeof query.cursor === 'string' && query.cursor.length > 0 ? query.cursor : null;
  return { limit, cursor };
}

function encodeCursor(doc) {
  if (!doc) return null;
  const date = doc.createdAt instanceof Date ? doc.createdAt.toISOString() : new Date(doc.createdAt).toISOString();
  return Buffer.from(`${date}|${doc._id.toString()}`).toString('base64url');
}

function decodeCursor(cursor) {
  if (!cursor) return null;
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8');
    const [iso, id] = raw.split('|');
    const createdAt = new Date(iso);
    if (Number.isNaN(createdAt.getTime()) || !id) return null;
    return { createdAt, id };
  } catch (_e) {
    return null;
  }
}

module.exports = { parsePagination, encodeCursor, decodeCursor };
