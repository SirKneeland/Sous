// Entitlement computation tests — covers all five entitlement states.
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  computeEntitlement,
  type SubscriptionRow,
  type UserRow,
} from './entitlement.js';

const CONFIG = { trialRecipeCap: 14 };
const NOW = new Date('2026-06-11T12:00:00Z');

function sub(overrides: Partial<SubscriptionRow>): SubscriptionRow {
  return {
    status: 'trialing',
    trial_ends_at: null,
    trial_recipes_used: 0,
    current_period_start: null,
    current_period_end: null,
    ...overrides,
  };
}

const NOT_BYOK: UserRow = { is_byok_eligible: false };
const BYOK: UserRow = { is_byok_eligible: true };

test('byok: BYOK-eligible user is byok regardless of subscription', () => {
  const r = computeEntitlement(BYOK, null, CONFIG, NOW);
  assert.equal(r.status, 'byok');
  assert.equal(r.hasAccess, true);
});

test('subscriber: active subscription within current period', () => {
  const r = computeEntitlement(
    NOT_BYOK,
    sub({
      status: 'active',
      current_period_start: '2026-06-01T00:00:00Z',
      current_period_end: '2026-07-01T00:00:00Z',
    }),
    CONFIG,
    NOW,
  );
  assert.equal(r.status, 'subscriber');
  assert.equal(r.hasAccess, true);
});

test('trialing: trial active by time and recipe count', () => {
  const r = computeEntitlement(
    NOT_BYOK,
    sub({ status: 'trialing', trial_ends_at: '2026-06-20T00:00:00Z', trial_recipes_used: 3 }),
    CONFIG,
    NOW,
  );
  assert.equal(r.status, 'trialing');
  assert.equal(r.hasAccess, true);
});

test('soft_wall: trial expired by time', () => {
  const r = computeEntitlement(
    NOT_BYOK,
    sub({ status: 'trialing', trial_ends_at: '2026-06-01T00:00:00Z', trial_recipes_used: 1 }),
    CONFIG,
    NOW,
  );
  assert.equal(r.status, 'soft_wall');
  assert.equal(r.hasAccess, false);
});

test('soft_wall: trial expired by recipe count even if time remains', () => {
  const r = computeEntitlement(
    NOT_BYOK,
    sub({ status: 'trialing', trial_ends_at: '2026-06-20T00:00:00Z', trial_recipes_used: 14 }),
    CONFIG,
    NOW,
  );
  assert.equal(r.status, 'soft_wall');
});

test('grace: lapsed subscription within the 7-day grace window', () => {
  const r = computeEntitlement(
    NOT_BYOK,
    sub({ status: 'lapsed', current_period_end: '2026-06-08T00:00:00Z' }), // 3 days ago
    CONFIG,
    NOW,
  );
  assert.equal(r.status, 'grace');
  assert.equal(r.hasAccess, true);
});

test('soft_wall: lapsed subscription past the grace window', () => {
  const r = computeEntitlement(
    NOT_BYOK,
    sub({ status: 'lapsed', current_period_end: '2026-06-01T00:00:00Z' }), // 10 days ago
    CONFIG,
    NOW,
  );
  assert.equal(r.status, 'soft_wall');
});

test('soft_wall: no subscription row at all', () => {
  const r = computeEntitlement(NOT_BYOK, null, CONFIG, NOW);
  assert.equal(r.status, 'soft_wall');
});

test('soft_wall: re-registered user stored as soft_wall', () => {
  const r = computeEntitlement(NOT_BYOK, sub({ status: 'soft_wall' }), CONFIG, NOW);
  assert.equal(r.status, 'soft_wall');
  assert.equal(r.hasAccess, false);
});

test('soft_wall: cancelled subscription', () => {
  const r = computeEntitlement(NOT_BYOK, sub({ status: 'cancelled' }), CONFIG, NOW);
  assert.equal(r.status, 'soft_wall');
});
