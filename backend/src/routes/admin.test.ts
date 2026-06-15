// Integration tests for the internal admin dashboard.
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
