// Integration tests for /api/v1/auth/* and the auth middleware.
// Uses an in-memory fake repo (no Supabase, no network).
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTestApp, signInWithApple } from '../test/harness.js';

test('new user: creates account, trialing entitlement, returns token', async () => {
  const { app, state } = buildTestApp();
  const { res, body } = await signInWithApple(app, 'apple-sub-new');

  assert.equal(res.status, 200);
  assert.ok(body.token, 'token returned');
  assert.ok(body.userId, 'userId returned');
  assert.equal(body.entitlement.status, 'trialing');
  // config echoed back, parsed from JSON strings.
  assert.equal(body.config.trial_duration_days, 14);

  // Side effects: one user, one trialing subscription, one session.
  assert.equal(state.users.length, 1);
  assert.equal(state.users[0]!.apple_sub, 'apple-sub-new');
  assert.equal(state.subscriptions.length, 1);
  assert.equal(state.subscriptions[0]!.status, 'trialing');
  assert.ok(state.subscriptions[0]!.trial_ends_at);
  assert.equal(state.sessions.length, 1);
});

test('returning user: same userId, no duplicate account, new session', async () => {
  const { app, state } = buildTestApp();
  const first = await signInWithApple(app, 'apple-sub-returning');
  const second = await signInWithApple(app, 'apple-sub-returning');

  assert.equal(first.body.userId, second.body.userId);
  assert.equal(state.users.length, 1, 'no duplicate user');
  assert.equal(state.subscriptions.length, 1, 'no duplicate subscription');
  assert.equal(state.sessions.length, 2, 'a fresh session each sign-in');
});

test('re-registration after deletion: account created but NO trial (soft_wall)', async () => {
  const { app, state } = buildTestApp({
    deletedAccounts: [{ apple_sub: 'apple-sub-deleted', deleted_at: '2026-01-01T00:00:00Z' }],
  });
  const { body } = await signInWithApple(app, 'apple-sub-deleted');

  assert.equal(body.entitlement.status, 'soft_wall');
  assert.equal(state.subscriptions.length, 1);
  assert.equal(state.subscriptions[0]!.status, 'soft_wall');
  assert.equal(state.subscriptions[0]!.trial_ends_at, null, 'no trial granted');
});

test('referral code: referred_by_user_id is set from a valid code', async () => {
  const { app, state } = buildTestApp();
  // Referrer signs up first, gets a referral code.
  const referrer = await signInWithApple(app, 'apple-sub-referrer');
  const referrerUser = state.users.find((u) => u.id === referrer.body.userId)!;
  const code = referrerUser.referral_code;

  // New user signs up with that code.
  const referred = await signInWithApple(app, 'apple-sub-referred', code);
  const referredUser = state.users.find((u) => u.id === referred.body.userId)!;

  assert.equal(referredUser.referred_by_user_id, referrer.body.userId);
});

test('referral code: unknown code is ignored (account still created)', async () => {
  const { app, state } = buildTestApp();
  const { res, body } = await signInWithApple(app, 'apple-sub-x', 'SOUS-ZZZZ');
  assert.equal(res.status, 200);
  const user = state.users.find((u) => u.id === body.userId)!;
  assert.equal(user.referred_by_user_id, null);
});

test('bad request: missing identityToken → 400', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/api/v1/auth/apple', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({}),
  });
  assert.equal(res.status, 400);
});

test('middleware: protected route with no token → 401', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/api/v1/config');
  assert.equal(res.status, 401);
});

test('middleware: revoked token → 401', async () => {
  const { app } = buildTestApp();
  const { body } = await signInWithApple(app, 'apple-sub-revoke');
  const token = body.token as string;

  // Sign out to revoke the session.
  const signout = await app.request('/api/v1/auth/signout', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(signout.status, 200);

  // The same token is now rejected on a protected route.
  const after = await app.request('/api/v1/config', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(after.status, 401);
});

test('account deletion: tombstones apple_sub and revokes sessions', async () => {
  const { app, state } = buildTestApp();
  const { body } = await signInWithApple(app, 'apple-sub-delete');
  const token = body.token as string;

  const del = await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(del.status, 200);

  assert.equal(state.deletedAccounts.length, 1);
  assert.equal(state.deletedAccounts[0]!.apple_sub, 'apple-sub-delete');
  assert.ok(state.users[0]!.is_deleted);
  assert.ok(state.sessions.every((s) => s.revoked));

  // Token no longer works.
  const after = await app.request('/api/v1/config', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(after.status, 401);
});
