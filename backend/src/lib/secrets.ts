// Constant-time secret comparison.
//
// Comparing secrets (admin keys, webhook shared secrets) with `===` leaks length
// and early-exit timing. We hash both sides to a fixed-width digest and compare
// with crypto.timingSafeEqual, so neither the length nor the contents leak via
// timing.

import { createHash, timingSafeEqual } from 'node:crypto';

export function timingSafeEqualStr(a: string, b: string): boolean {
  const da = createHash('sha256').update(a, 'utf8').digest();
  const db = createHash('sha256').update(b, 'utf8').digest();
  // Digests are always 32 bytes, so timingSafeEqual's equal-length precondition holds.
  return timingSafeEqual(da, db);
}
