// Session token sign/verify tests.
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { signSessionToken, verifySessionToken } from './tokens.js';

const SECRET = 'unit-test-secret';

test('signs and verifies a session token round-trip', async () => {
  const { token, expiresAt } = await signSessionToken(
    { userId: 'user-123', sessionId: 'sess-abc' },
    SECRET,
  );
  assert.ok(token.length > 0);
  // 30-day expiry, roughly.
  const days = (expiresAt.getTime() - Date.now()) / (24 * 60 * 60 * 1000);
  assert.ok(days > 29.9 && days < 30.1, `expected ~30 days, got ${days}`);

  const claims = await verifySessionToken(token, SECRET);
  assert.equal(claims.userId, 'user-123');
  assert.equal(claims.sessionId, 'sess-abc');
});

test('rejects a token signed with a different secret', async () => {
  const { token } = await signSessionToken(
    { userId: 'u', sessionId: 's' },
    SECRET,
  );
  await assert.rejects(() => verifySessionToken(token, 'wrong-secret'));
});

test('rejects an already-expired token', async () => {
  const past = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
  const { token } = await signSessionToken(
    { userId: 'u', sessionId: 's' },
    SECRET,
    past,
  );
  await assert.rejects(() => verifySessionToken(token, SECRET));
});
