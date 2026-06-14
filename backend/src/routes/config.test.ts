// Integration tests for /api/v1/config, /subscription/status, /health, and stubs.
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTestApp, signInWithApple, readJson } from '../test/harness.js';

test('health: GET /health returns ok with no auth', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/health');
  assert.equal(res.status, 200);
  assert.deepEqual(await readJson(res), { status: 'ok' });
});

test('config: returns seed config values and entitlement', async () => {
  const { app } = buildTestApp();
  const { body } = await signInWithApple(app, 'apple-sub-config');
  const token = body.token as string;

  const res = await app.request('/api/v1/config', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(res.status, 200);
  const data = await readJson(res);
  assert.equal(data.config.trial_duration_days, 14);
  assert.equal(data.config.trial_recipe_cap, 14);
  assert.equal(data.config.paid_recipe_cap, 100);
  assert.equal(data.config.byok_cutoff_enabled, false);
  assert.equal(data.config.byok_cutoff_date, null);
  assert.equal(data.entitlement.status, 'trialing');
});

test('subscription/status: returns entitlement and the subscription row', async () => {
  const { app } = buildTestApp();
  const { body } = await signInWithApple(app, 'apple-sub-sub');
  const token = body.token as string;

  const res = await app.request('/api/v1/subscription/status', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(res.status, 200);
  const data = await readJson(res);
  assert.equal(data.entitlement.status, 'trialing');
  assert.equal(data.subscription.status, 'trialing');
});

test('usage/recipe: requires auth and increments the period counter', async () => {
  const { app } = buildTestApp();
  const { body } = await signInWithApple(app, 'apple-sub-stub');
  const token = body.token as string;

  // No auth → 401.
  const noAuth = await app.request('/api/v1/usage/recipe', { method: 'POST' });
  assert.equal(noAuth.status, 401);

  // With auth → 200 with updated count (implemented in Project 3).
  const res = await app.request('/api/v1/usage/recipe', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(res.status, 200);
  const data = await readJson(res);
  assert.equal(data.recipesUsed, 1);
});

test('stubs: sync/recipes remains a Project 3 stub (501)', async () => {
  const { app } = buildTestApp();
  const { body } = await signInWithApple(app, 'apple-sub-stub2');
  const token = body.token as string;
  const auth = { Authorization: `Bearer ${token}` };

  // proxy/chat is implemented in Project 3; auth is still required.
  const chatNoAuth = await app.request('/api/v1/proxy/chat', { method: 'POST' });
  assert.equal(chatNoAuth.status, 401);

  // Recipe-session sync was not in scope for Project 3 — still a stub.
  const recipes = await app.request('/api/v1/sync/recipes', { headers: auth });
  assert.equal(recipes.status, 501);
});
