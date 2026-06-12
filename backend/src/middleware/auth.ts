// Auth middleware. Protects every route except /health and /auth/apple.
//
// Two-stage verification:
//   1. Cryptographic — the Bearer JWT must have a valid signature and not be
//      expired (verifySessionToken).
//   2. Stateful — the token must exist in the `sessions` table, not be revoked,
//      and not be past its stored expiry (so sign-out / account deletion take
//      effect immediately).
// On success, attaches `userId` to the context. Any failure → 401.

import { createMiddleware } from 'hono/factory';
import type { HonoEnv } from '../types.js';
import { verifySessionToken } from '../lib/tokens.js';

export const authMiddleware = createMiddleware<HonoEnv>(async (c, next) => {
  const deps = c.get('deps');

  const header = c.req.header('Authorization') ?? '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return c.json({ error: 'unauthorized', message: 'Missing Bearer token' }, 401);
  }
  const token = match[1]!.trim();

  // Stage 1: cryptographic verification.
  let claims;
  try {
    claims = await verifySessionToken(token, deps.jwtSecret);
  } catch {
    return c.json({ error: 'unauthorized', message: 'Invalid or expired token' }, 401);
  }

  // Stage 2: stateful verification against the sessions table.
  const session = await deps.repo.getSessionByToken(token);
  if (!session) {
    return c.json({ error: 'unauthorized', message: 'Session not found' }, 401);
  }
  if (session.revoked) {
    return c.json({ error: 'unauthorized', message: 'Session revoked' }, 401);
  }
  if (new Date(session.expires_at) <= new Date()) {
    return c.json({ error: 'unauthorized', message: 'Session expired' }, 401);
  }
  if (session.user_id !== claims.userId) {
    return c.json({ error: 'unauthorized', message: 'Token/session mismatch' }, 401);
  }

  c.set('userId', claims.userId);
  await next();
});
