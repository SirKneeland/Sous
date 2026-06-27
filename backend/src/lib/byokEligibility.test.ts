// Unit tests for computeByokEligibility — pure function, no I/O.
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeByokEligibility } from './byokEligibility.js';

const cutoff = new Date('2025-01-01T00:00:00Z');
const before = new Date('2024-12-31T23:59:59Z'); // strictly before cutoff
const after  = new Date('2025-01-01T00:00:01Z'); // strictly after cutoff
const atCutoff = new Date('2025-01-01T00:00:00Z'); // exactly at cutoff (not before)

test('byokEligibility: disabled → false regardless of dates', () => {
  assert.equal(computeByokEligibility(before, false, cutoff), false);
  assert.equal(computeByokEligibility(before, false, null), false);
  assert.equal(computeByokEligibility(after, false, cutoff), false);
});

test('byokEligibility: enabled + null cutoffDate → false (misconfiguration safe)', () => {
  assert.equal(computeByokEligibility(before, true, null), false);
});

test('byokEligibility: enabled + accountCreatedAt before cutoff → true', () => {
  assert.equal(computeByokEligibility(before, true, cutoff), true);
});

test('byokEligibility: enabled + accountCreatedAt after cutoff → false', () => {
  assert.equal(computeByokEligibility(after, true, cutoff), false);
});

test('byokEligibility: enabled + accountCreatedAt exactly at cutoff → false (not strictly before)', () => {
  assert.equal(computeByokEligibility(atCutoff, true, cutoff), false);
});
