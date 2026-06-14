// Integration tests for /api/v1/sync/* (preferences, memories, profile) and the
// enriched /subscription/status profile. Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTestApp, signInWithApple, readJson } from '../test/harness.js';

/** Sign in and return { app, state, token } for an authenticated request. */
async function signedIn(sub: string) {
  const ctx = buildTestApp();
  const { body } = await signInWithApple(ctx.app, sub);
  return { ...ctx, token: body.token as string, userId: body.userId as string };
}

test('sync/preferences: requires auth', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/api/v1/sync/preferences');
  assert.equal(res.status, 401);
});

test('sync/preferences: GET returns empty defaults before any save', async () => {
  const { app, token } = await signedIn('prefs-empty');
  const res = await app.request('/api/v1/sync/preferences', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(res.status, 200);
  const data = await readJson(res);
  assert.deepEqual(data.preferences, {
    hardAvoids: [],
    servingSize: null,
    equipment: [],
    customInstructions: null,
    personalityMode: null,
  });
});

test('sync/preferences: PUT then GET round-trips', async () => {
  const { app, token } = await signedIn('prefs-roundtrip');
  const auth = { Authorization: `Bearer ${token}`, 'content-type': 'application/json' };

  const put = await app.request('/api/v1/sync/preferences', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({
      hardAvoids: ['cilantro', 'shellfish'],
      servingSize: 4,
      equipment: ['cast iron'],
      customInstructions: 'gas and induction settings',
      personalityMode: 'unhinged',
    }),
  });
  assert.equal(put.status, 200);

  const get = await app.request('/api/v1/sync/preferences', {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await readJson(get);
  assert.deepEqual(data.preferences.hardAvoids, ['cilantro', 'shellfish']);
  assert.equal(data.preferences.servingSize, 4);
  assert.deepEqual(data.preferences.equipment, ['cast iron']);
  assert.equal(data.preferences.customInstructions, 'gas and induction settings');
  // 'unhinged' is an accepted personality mode.
  assert.equal(data.preferences.personalityMode, 'unhinged');
});

test('sync/preferences: unknown personality mode is coerced to null', async () => {
  const { app, token } = await signedIn('prefs-bad-mode');
  const auth = { Authorization: `Bearer ${token}`, 'content-type': 'application/json' };
  const put = await app.request('/api/v1/sync/preferences', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({ personalityMode: 'chaotic-evil' }),
  });
  assert.equal(put.status, 200);
  const data = await readJson(put);
  assert.equal(data.preferences.personalityMode, null);
});

test('sync/memories: PUT replaces the full list and GET returns it', async () => {
  const { app, token } = await signedIn('mem-replace');
  const auth = { Authorization: `Bearer ${token}`, 'content-type': 'application/json' };

  const first = await app.request('/api/v1/sync/memories', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({
      memories: [
        { text: 'hates cilantro', createdAt: '2026-01-01T00:00:00.000Z' },
        { text: 'cooking for two kids', createdAt: '2026-01-02T00:00:00.000Z' },
      ],
    }),
  });
  assert.equal(first.status, 200);
  const firstData = await readJson(first);
  assert.equal(firstData.memories.length, 2);
  assert.equal(firstData.memories[0].text, 'hates cilantro');
  assert.ok(firstData.memories[0].id, 'server assigns an id when none supplied');

  // Replace with a single memory — the prior two must be gone.
  const second = await app.request('/api/v1/sync/memories', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({ memories: [{ text: 'prefers metric' }] }),
  });
  assert.equal(second.status, 200);

  const get = await app.request('/api/v1/sync/memories', {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await readJson(get);
  assert.equal(data.memories.length, 1);
  assert.equal(data.memories[0].text, 'prefers metric');
});

test('sync/memories: empty list clears all memories', async () => {
  const { app, token } = await signedIn('mem-clear');
  const auth = { Authorization: `Bearer ${token}`, 'content-type': 'application/json' };
  await app.request('/api/v1/sync/memories', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({ memories: [{ text: 'one' }] }),
  });
  const cleared = await app.request('/api/v1/sync/memories', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({ memories: [] }),
  });
  assert.equal(cleared.status, 200);
  const data = await readJson(cleared);
  assert.equal(data.memories.length, 0);
});

test('sync/profile: PUT updates the display name; status reflects it', async () => {
  const { app, token } = await signedIn('profile-name');
  const auth = { Authorization: `Bearer ${token}`, 'content-type': 'application/json' };

  const put = await app.request('/api/v1/sync/profile', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({ displayName: 'Chef John' }),
  });
  assert.equal(put.status, 200);
  assert.equal((await readJson(put)).displayName, 'Chef John');

  const status = await app.request('/api/v1/subscription/status', {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await readJson(status);
  assert.equal(data.profile.displayName, 'Chef John');
  assert.equal(data.profile.email, 'profile-name@example.test');
  assert.ok(data.profile.referralCode, 'referral code is exposed read-only');
  assert.equal(data.profile.isByokEligible, false);
});

test('auth/apple: response includes the user profile', async () => {
  const { app } = buildTestApp();
  const { body } = await signInWithApple(app, 'apple-sub-profile');
  assert.ok(body.profile, 'auth response carries a profile object');
  assert.equal(body.profile.email, 'apple-sub-profile@example.test');
  assert.ok(body.profile.referralCode);
});

test('sync: preferences and memories are isolated per user', async () => {
  const { app } = buildTestApp();
  const a = await signInWithApple(app, 'user-a');
  const b = await signInWithApple(app, 'user-b');
  const authA = { Authorization: `Bearer ${a.body.token}`, 'content-type': 'application/json' };

  await app.request('/api/v1/sync/memories', {
    method: 'PUT',
    headers: authA,
    body: JSON.stringify({ memories: [{ text: 'a-only memory' }] }),
  });

  const bMem = await app.request('/api/v1/sync/memories', {
    headers: { Authorization: `Bearer ${b.body.token}` },
  });
  const bData = await readJson(bMem);
  assert.equal(bData.memories.length, 0, 'user B does not see user A memories');
});
