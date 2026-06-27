// Integration tests for /api/v1/auth/* and the auth middleware.
// Uses an in-memory fake repo (no Supabase, no network).
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildTestApp,
  signInWithApple,
  TEST_DELETION_HASH_SECRET,
} from '../test/harness.js';
import { hashAppleSub } from '../lib/secrets.js';

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
  // The tombstone stores a HASH of apple_sub; seed it the same way the backend does.
  const { app, state } = buildTestApp({
    deletedAccounts: [
      {
        apple_sub: hashAppleSub('apple-sub-deleted', TEST_DELETION_HASH_SECRET),
        deleted_at: '2026-01-01T00:00:00Z',
      },
    ],
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

/**
 * Sign in a user and seed PII (display name + phone), a preferences row, memories,
 * and capture the subscription row, so deletion behavior can be asserted end to end.
 */
async function signInAndSeed(app: ReturnType<typeof buildTestApp>['app'], state: ReturnType<typeof buildTestApp>['state'], appleSub: string) {
  const { body } = await signInWithApple(app, appleSub);
  const token = body.token as string;
  const userId = body.userId as string;

  const user = state.users.find((u) => u.id === userId)!;
  user.display_name = 'Jane Cook';
  user.phone_number = '+15555550123';

  state.preferences.push({
    user_id: userId,
    hard_avoids: ['cilantro'],
    serving_size: 2,
    equipment: ['oven'],
    custom_instructions: 'no spice',
    personality_mode: 'normal',
    updated_at: '2026-01-01T00:00:00Z',
  });
  state.memories.push({
    id: 'mem-1',
    user_id: userId,
    text: 'Allergic to peanuts',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  });

  return { token, userId, user };
}

test('account deletion: scrubs all PII on the user row, marks it deleted', async () => {
  const { app, state } = buildTestApp();
  const { token, userId } = await signInAndSeed(app, state, 'apple-sub-delete');

  const del = await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(del.status, 200);

  const user = state.users.find((u) => u.id === userId)!;
  assert.equal(user.email, null, 'email scrubbed');
  assert.equal(user.display_name, null, 'display_name scrubbed');
  assert.equal(user.phone_number, null, 'phone_number scrubbed');
  assert.equal(user.apple_sub, null, 'apple_sub scrubbed');
  assert.ok(user.is_deleted, 'is_deleted set');
  assert.ok(user.deleted_at, 'deleted_at set');
  // Non-PII retained.
  assert.ok(user.referral_code, 'referral_code retained');
  assert.equal(user.id, userId, 'id retained');
});

test('account deletion: hard-deletes the preferences row', async () => {
  const { app, state } = buildTestApp();
  const { token, userId } = await signInAndSeed(app, state, 'apple-sub-prefs');
  assert.equal(state.preferences.filter((p) => p.user_id === userId).length, 1);

  await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });

  assert.equal(
    state.preferences.filter((p) => p.user_id === userId).length,
    0,
    'preferences hard-deleted',
  );
});

test('account deletion: hard-deletes memories rows', async () => {
  const { app, state } = buildTestApp();
  const { token, userId } = await signInAndSeed(app, state, 'apple-sub-mem');
  assert.equal(state.memories.filter((m) => m.user_id === userId).length, 1);

  await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });

  assert.equal(
    state.memories.filter((m) => m.user_id === userId).length,
    0,
    'memories hard-deleted',
  );
});

test('account deletion: leaves the subscription row completely unchanged', async () => {
  const { app, state } = buildTestApp();
  const { token, userId } = await signInAndSeed(app, state, 'apple-sub-sub');

  // Simulate a real billing history on the subscription before deletion.
  const sub = state.subscriptions.find((s) => s.user_id === userId)!;
  sub.apple_original_transaction_id = 'orig-txn-123';
  sub.apple_latest_receipt = 'receipt-blob-abc';
  sub.status = 'active';
  const before = { ...sub };

  await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });

  const after = state.subscriptions.find((s) => s.user_id === userId)!;
  assert.deepEqual(after, before, 'subscription row untouched by deletion');
  assert.equal(after.apple_original_transaction_id, 'orig-txn-123');
  assert.equal(after.apple_latest_receipt, 'receipt-blob-abc');
});

test('account deletion: tombstone stores a HASH, not the raw apple_sub', async () => {
  const { app, state } = buildTestApp();
  const { token } = await signInAndSeed(app, state, 'apple-sub-hash');

  await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });

  assert.equal(state.deletedAccounts.length, 1);
  const stored = state.deletedAccounts[0]!.apple_sub;
  assert.notEqual(stored, 'apple-sub-hash', 'raw apple_sub is NOT stored');
  assert.equal(
    stored,
    hashAppleSub('apple-sub-hash', TEST_DELETION_HASH_SECRET),
    'stored value is the HMAC of apple_sub',
  );
});

test('account deletion: revokes all sessions; token stops working', async () => {
  const { app, state } = buildTestApp();
  const { token, userId } = await signInAndSeed(app, state, 'apple-sub-revoke-del');

  const del = await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(del.status, 200);
  assert.ok(
    state.sessions.filter((s) => s.user_id === userId).every((s) => s.revoked),
    'all sessions revoked',
  );

  const after = await app.request('/api/v1/config', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(after.status, 401);
});

test('account deletion: a half-deleted row (is_deleted but apple_sub intact) is actually purged, not skipped', async () => {
  // Simulates a prior INCOMPLETE delete (legacy soft-delete-only, or a purge that
  // never finished): is_deleted is true but PII is still present and the session is
  // live. The handler must NOT treat this as "already handled" — it must purge.
  const { app, state } = buildTestApp();
  const { token, userId } = await signInAndSeed(app, state, 'apple-sub-halfdel');
  const user = state.users.find((u) => u.id === userId)!;
  user.is_deleted = true; // flagged deleted, but apple_sub + PII + session remain

  const del = await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(del.status, 200);

  const after = state.users.find((u) => u.id === userId)!;
  assert.equal(after.apple_sub, null, 'apple_sub now scrubbed (purge actually ran)');
  assert.equal(after.email, null);
  assert.equal(state.preferences.filter((p) => p.user_id === userId).length, 0);
  assert.equal(state.memories.filter((m) => m.user_id === userId).length, 0);
  assert.equal(state.deletedAccounts.length, 1, 'hashed tombstone written');
  assert.equal(
    state.deletedAccounts[0]!.apple_sub,
    hashAppleSub('apple-sub-halfdel', TEST_DELETION_HASH_SECRET),
  );
});

test('re-registration after deletion still denies a fresh trial (hashed lookup works)', async () => {
  const { app, state } = buildTestApp();
  const { token } = await signInAndSeed(app, state, 'apple-sub-rereg');

  await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });

  // Same Apple identity signs in again → new account, but soft_wall (no fresh trial).
  const { body } = await signInWithApple(app, 'apple-sub-rereg');
  assert.equal(body.entitlement.status, 'soft_wall', 'no fresh trial after deletion');
  const newSub = state.subscriptions.find((s) => s.user_id === body.userId)!;
  assert.equal(newSub.status, 'soft_wall');
  assert.equal(newSub.trial_ends_at, null, 'no trial granted');
});

test('normal re-registration for a never-deleted identity is unaffected', async () => {
  const { app } = buildTestApp();
  // Unrelated account is deleted; a DIFFERENT identity must still get a trial.
  const deleted = await signInWithApple(app, 'apple-sub-other');
  await app.request('/api/v1/auth/account', {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${deleted.body.token}` },
  });

  const { body } = await signInWithApple(app, 'apple-sub-fresh');
  assert.equal(body.entitlement.status, 'trialing', 'fresh identity gets a normal trial');
});

// --- BYOK eligibility at signup ---

test('signup: is_byok_eligible=false when cutoff is disabled (default config)', async () => {
  // Default config has byok_cutoff_enabled=false.
  const { app, state } = buildTestApp();
  await signInWithApple(app, 'apple-byok-disabled');
  assert.equal(state.users[0]!.is_byok_eligible, false);
});

test('signup: is_byok_eligible=true when cutoff enabled and account created before cutoff date', async () => {
  // Clock is pinned to before the cutoff date.
  const cutoffDate = new Date('2030-01-01T00:00:00Z');
  const signupTime = new Date('2024-06-01T00:00:00Z'); // before cutoff

  const { app, state } = buildTestApp(
    {
      config: {
        trial_duration_days: '14',
        trial_recipe_cap: '14',
        paid_recipe_cap: '100',
        byok_cutoff_enabled: 'true',
        byok_cutoff_date: JSON.stringify(cutoffDate.toISOString()),
        abuse_recipes_per_day: '20',
        abuse_recipes_per_period: '150',
        abuse_chat_per_recipe: '200',
        abuse_off_topic_rate: '0.30',
        off_topic_threshold: '0.8',
      },
    },
    { now: () => signupTime },
  );
  await signInWithApple(app, 'apple-byok-eligible');
  assert.equal(state.users[0]!.is_byok_eligible, true);
});

test('signup: is_byok_eligible=false when cutoff enabled but account created after cutoff date', async () => {
  const cutoffDate = new Date('2020-01-01T00:00:00Z');
  const signupTime = new Date('2024-06-01T00:00:00Z'); // after cutoff

  const { app, state } = buildTestApp(
    {
      config: {
        trial_duration_days: '14',
        trial_recipe_cap: '14',
        paid_recipe_cap: '100',
        byok_cutoff_enabled: 'true',
        byok_cutoff_date: JSON.stringify(cutoffDate.toISOString()),
        abuse_recipes_per_day: '20',
        abuse_recipes_per_period: '150',
        abuse_chat_per_recipe: '200',
        abuse_off_topic_rate: '0.30',
        off_topic_threshold: '0.8',
      },
    },
    { now: () => signupTime },
  );
  await signInWithApple(app, 'apple-byok-ineligible');
  assert.equal(state.users[0]!.is_byok_eligible, false);
});

test('signup: is_byok_eligible=false when cutoff enabled but cutoff date is null (misconfiguration)', async () => {
  const { app, state } = buildTestApp({
    config: {
      trial_duration_days: '14',
      trial_recipe_cap: '14',
      paid_recipe_cap: '100',
      byok_cutoff_enabled: 'true',
      byok_cutoff_date: 'null',
      abuse_recipes_per_day: '20',
      abuse_recipes_per_period: '150',
      abuse_chat_per_recipe: '200',
      abuse_off_topic_rate: '0.30',
      off_topic_threshold: '0.8',
    },
  });
  await signInWithApple(app, 'apple-byok-null-date');
  assert.equal(state.users[0]!.is_byok_eligible, false);
});
