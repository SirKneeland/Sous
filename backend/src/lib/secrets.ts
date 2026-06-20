// Constant-time secret comparison.
//
// Comparing secrets (admin keys, webhook shared secrets) with `===` leaks length
// and early-exit timing. We hash both sides to a fixed-width digest and compare
// with crypto.timingSafeEqual, so neither the length nor the contents leak via
// timing.

import { createHash, createHmac, timingSafeEqual } from 'node:crypto';

export function timingSafeEqualStr(a: string, b: string): boolean {
  const da = createHash('sha256').update(a, 'utf8').digest();
  const db = createHash('sha256').update(b, 'utf8').digest();
  // Digests are always 32 bytes, so timingSafeEqual's equal-length precondition holds.
  return timingSafeEqual(da, db);
}

// One-way keyed hash of an Apple subject identifier, used as the `deleted_accounts`
// tombstone key. Storing the raw apple_sub would leave an identifier for a deleted
// account in plaintext forever; an HMAC keeps the tombstone useful (the same input
// always hashes to the same value, so re-registration can still be detected) while
// being non-reversible without ACCOUNT_DELETION_HASH_SECRET. Hex digest so the value
// is a plain string suitable for a text primary key.
export function hashAppleSub(appleSub: string, secret: string): string {
  return createHmac('sha256', secret).update(appleSub, 'utf8').digest('hex');
}
