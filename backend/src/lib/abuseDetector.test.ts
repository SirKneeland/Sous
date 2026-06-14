// Unit tests for the abuse detector. Uses the in-memory fake repo directly.
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createFakeRepo } from '../test/fakeRepo.js';
import { abuseConfigFrom, checkAbuse } from './abuseDetector.js';
import type { UsageEventRow } from '../db/types.js';

const USER = 'user-abuse';
const PERIOD = '2026-06';

function userRow(id: string) {
  return {
    id,
    apple_sub: id,
    email: null,
    display_name: null,
    phone_number: null,
    account_created_at: new Date().toISOString(),
    is_byok_eligible: false,
    referral_code: `SOUS-${id}`,
    referred_by_user_id: null,
    is_deleted: false,
    deleted_at: null,
    abuse_flag: false,
    abuse_flag_reason: null,
  };
}

function newRecipeEvents(n: number, when: Date): UsageEventRow[] {
  return Array.from({ length: n }, () => ({
    id: Math.random().toString(36),
    user_id: USER,
    recipe_id: 'r1',
    request_type: 'text' as const,
    is_new_recipe: true,
    input_tokens: 1,
    output_tokens: 1,
    model: 'gpt-5.4-mini',
    estimated_cost_usd: 0,
    request_outcome: 'success' as const,
    voice_duration_seconds: null,
    voice_tts_characters: null,
    off_topic_flagged: false,
    billing_period: PERIOD,
    timestamp: when.toISOString(),
  }));
}

test('abuse: flags when daily new-recipe threshold is exceeded', async () => {
  const now = new Date('2026-06-15T12:00:00Z');
  const { repo, state } = createFakeRepo({
    users: [userRow(USER)],
    usageEvents: newRecipeEvents(21, now), // threshold is 20/day
  });

  const reason = await checkAbuse({
    repo,
    config: abuseConfigFrom(state.config),
    userId: USER,
    recipeId: 'r1',
    billingPeriod: PERIOD,
    now,
  });

  assert.ok(reason, 'expected a flag reason');
  assert.equal(state.users[0]!.abuse_flag, true);
  assert.ok(state.users[0]!.abuse_flag_reason?.includes('today'));
});

test('abuse: flags when chat-per-recipe threshold is exceeded', async () => {
  const now = new Date('2026-06-15T12:00:00Z');
  // 201 events on one recipe (threshold 200), spread over time so the daily
  // window does not also trip (keeps the asserted reason specific).
  const events: UsageEventRow[] = newRecipeEvents(201, new Date('2026-06-01T00:00:00Z')).map(
    (e) => ({ ...e, is_new_recipe: false }),
  );
  const { repo, state } = createFakeRepo({ users: [userRow(USER)], usageEvents: events });

  const reason = await checkAbuse({
    repo,
    config: abuseConfigFrom(state.config),
    userId: USER,
    recipeId: 'r1',
    billingPeriod: PERIOD,
    now,
  });

  assert.ok(reason?.includes('one recipe'));
  assert.equal(state.users[0]!.abuse_flag, true);
});

test('abuse: does not flag normal usage', async () => {
  const now = new Date('2026-06-15T12:00:00Z');
  const { repo, state } = createFakeRepo({
    users: [userRow(USER)],
    usageEvents: newRecipeEvents(3, now),
  });

  const reason = await checkAbuse({
    repo,
    config: abuseConfigFrom(state.config),
    userId: USER,
    recipeId: 'r1',
    billingPeriod: PERIOD,
    now,
  });

  assert.equal(reason, null);
  assert.equal(state.users[0]!.abuse_flag, false);
});
