// Integration tests for /api/v1/usage/* (recipe telemetry + summary).
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTestApp, signInWithApple, readJson } from '../test/harness.js';

async function authedToken(app: ReturnType<typeof buildTestApp>['app'], sub: string) {
  const { body } = await signInWithApple(app, sub);
  return body.token as string;
}

test('usage/recipe: increments period + trial counters and returns new counts', async () => {
  const { app, state } = buildTestApp();
  const token = await authedToken(app, 'apple-usage-1');

  const first = await readJson(
    await app.request('/api/v1/usage/recipe', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    }),
  );
  // New trial user → both counters advance to 1.
  assert.equal(first.recipesUsed, 1);
  assert.equal(first.trialRecipesUsed, 1);
  assert.equal(state.subscriptions[0]!.trial_recipes_used, 1);

  const second = await readJson(
    await app.request('/api/v1/usage/recipe', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    }),
  );
  assert.equal(second.recipesUsed, 2);
  assert.equal(second.trialRecipesUsed, 2);
});

test('usage/recipe + usage/summary: count surfaces in the trial summary', async () => {
  const { app } = buildTestApp();
  const token = await authedToken(app, 'apple-usage-1b');

  await app.request('/api/v1/usage/recipe', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });

  const summary = await readJson(
    await app.request('/api/v1/usage/summary', {
      headers: { Authorization: `Bearer ${token}` },
    }),
  );
  // The bug was "stuck at 0" — confirm the first recipe shows as 1 of 14.
  assert.equal(summary.entitlement, 'trialing');
  assert.equal(summary.trialRecipesUsed, 1);
  assert.equal(summary.trialRecipeCap, 14);
});

test('usage/summary: trial user sees trial-specific counts', async () => {
  const { app, state } = buildTestApp();
  const token = await authedToken(app, 'apple-usage-2');
  // Simulate prior usage.
  state.subscriptions[0]!.trial_recipes_used = 5;

  const res = await app.request('/api/v1/usage/summary', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(res.status, 200);
  const data = await readJson(res);

  assert.equal(data.entitlement, 'trialing');
  assert.equal(data.recipeCap, 100);
  assert.equal(typeof data.billingPeriod, 'string');
  assert.ok(data.resetsInDays >= 0);
  // Trial-specific fields present.
  assert.equal(data.trialRecipesUsed, 5);
  assert.equal(data.trialRecipeCap, 14);
  assert.ok(data.trialDaysRemaining >= 0);
});

test('usage/summary: paid subscriber sees monthly recipe count, no trial fields', async () => {
  const { app, state } = buildTestApp();
  const token = await authedToken(app, 'apple-usage-3');

  // Promote to an active subscriber within its period.
  const sub = state.subscriptions[0]!;
  sub.status = 'active';
  sub.current_period_end = new Date(Date.now() + 20 * 24 * 60 * 60 * 1000).toISOString();

  // Record some monthly recipe usage.
  const userId = state.users[0]!.id;
  const period = new Date().toISOString().slice(0, 7);
  state.recipeCapCounters.push({ user_id: userId, billing_period: period, recipes_used: 12 });

  const res = await app.request('/api/v1/usage/summary', {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await readJson(res);

  assert.equal(data.entitlement, 'subscriber');
  assert.equal(data.recipesUsed, 12);
  assert.equal(data.recipeCap, 100);
  assert.equal(data.trialRecipesUsed, undefined);
});

test('usage/summary: requires auth', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/api/v1/usage/summary');
  assert.equal(res.status, 401);
});
