// Integration tests for the internal admin dashboard and admin-only mutations.
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTestApp, signInWithApple, readJson, TEST_ADMIN_KEY } from '../test/harness.js';

function chatBody(text: string) {
  return {
    model: 'gpt-5.4-mini',
    messages: [{ role: 'user', content: text }],
  };
}

test('admin/dashboard: rejects missing or wrong key', async () => {
  const { app } = buildTestApp();
  const noKey = await app.request('/api/v1/admin/dashboard');
  assert.equal(noKey.status, 401);

  const wrong = await app.request('/api/v1/admin/dashboard', {
    headers: { 'X-Admin-Key': 'nope' },
  });
  assert.equal(wrong.status, 401);
});

test('admin/dashboard: returns aggregate counts', async () => {
  const { app, state } = buildTestApp();

  // One trial user who creates a recipe through the proxy.
  const { body } = await signInWithApple(app, 'apple-admin-1');
  const token = body.token as string;
  await app.request('/api/v1/proxy/chat', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      'X-Sous-Is-New-Recipe': 'true',
      'X-Sous-Recipe-Id': 'recipe-1',
    },
    body: JSON.stringify(chatBody('Make me a pizza recipe')),
  });
  // The client records the created recipe (the counting path; proxy is read-only).
  await app.request('/api/v1/usage/recipe', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });

  // A second, BYOK user.
  await signInWithApple(app, 'apple-admin-2');
  state.users[1]!.is_byok_eligible = true;

  // Flag the first account.
  state.users[0]!.abuse_flag = true;
  state.users[0]!.abuse_flag_reason = 'test flag';

  const res = await app.request('/api/v1/admin/dashboard', {
    headers: { 'X-Admin-Key': TEST_ADMIN_KEY },
  });
  assert.equal(res.status, 200);
  const data = await readJson(res);

  assert.equal(data.activeUsers.trial, 1);
  assert.equal(data.activeUsers.byok, 1);
  assert.ok(data.costThisMonth.totalUsd > 0);
  assert.ok(data.costThisMonth.byModality.text > 0);
  assert.equal(data.flaggedAccounts, 1);
  assert.equal(data.topUsersByRecipes[0].recipes, 1);
});

// --- POST /admin/users/:id/byok-eligible ---

test('admin/byok-eligible: rejects missing or wrong key', async () => {
  const { app } = buildTestApp();
  const { body: signIn } = await signInWithApple(app, 'apple-byok-auth-1');
  const userId = signIn.userId as string;

  const noKey = await app.request(`/api/v1/admin/users/${userId}/byok-eligible`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ eligible: true }),
  });
  assert.equal(noKey.status, 401);

  const wrongKey = await app.request(`/api/v1/admin/users/${userId}/byok-eligible`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'X-Admin-Key': 'wrong' },
    body: JSON.stringify({ eligible: true }),
  });
  assert.equal(wrongKey.status, 401);
});

test('admin/byok-eligible: 404 for unknown user id', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/api/v1/admin/users/00000000-0000-0000-0000-000000000000/byok-eligible', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'X-Admin-Key': TEST_ADMIN_KEY },
    body: JSON.stringify({ eligible: true }),
  });
  assert.equal(res.status, 404);
});

test('admin/byok-eligible: sets is_byok_eligible to true on an existing user', async () => {
  const { app, state } = buildTestApp();
  const { body: signIn } = await signInWithApple(app, 'apple-byok-set-1');
  const userId = signIn.userId as string;

  assert.equal(state.users.find((u) => u.id === userId)!.is_byok_eligible, false);

  const res = await app.request(`/api/v1/admin/users/${userId}/byok-eligible`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'X-Admin-Key': TEST_ADMIN_KEY },
    body: JSON.stringify({ eligible: true }),
  });
  assert.equal(res.status, 200);
  const data = await readJson(res);
  assert.equal(data.ok, true);
  assert.equal(data.eligible, true);

  assert.equal(state.users.find((u) => u.id === userId)!.is_byok_eligible, true);
});

test('admin/byok-eligible: sets is_byok_eligible to false on an existing user', async () => {
  const { app, state } = buildTestApp();
  const { body: signIn } = await signInWithApple(app, 'apple-byok-set-2');
  const userId = signIn.userId as string;

  // Manually set to true first.
  state.users.find((u) => u.id === userId)!.is_byok_eligible = true;

  const res = await app.request(`/api/v1/admin/users/${userId}/byok-eligible`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'X-Admin-Key': TEST_ADMIN_KEY },
    body: JSON.stringify({ eligible: false }),
  });
  assert.equal(res.status, 200);
  assert.equal(state.users.find((u) => u.id === userId)!.is_byok_eligible, false);
});

test('admin/byok-eligible: 400 when body is missing eligible field', async () => {
  const { app } = buildTestApp();
  const { body: signIn } = await signInWithApple(app, 'apple-byok-bad-body');
  const userId = signIn.userId as string;

  const res = await app.request(`/api/v1/admin/users/${userId}/byok-eligible`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'X-Admin-Key': TEST_ADMIN_KEY },
    body: JSON.stringify({ enabled: true }), // wrong field name
  });
  assert.equal(res.status, 400);
});
