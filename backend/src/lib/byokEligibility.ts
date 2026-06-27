// Pure function: determine whether an account created at a given time is eligible
// for BYOK (bring-your-own-key) access, based on the current cutoff config.
//
// Called once at signup and never recomputed — changing the config later does
// not retroactively affect existing accounts.

/**
 * Returns true when the account qualifies for BYOK access:
 *   - cutoff must be enabled
 *   - cutoffDate must be set (null = misconfigured → false, fail safe)
 *   - accountCreatedAt must be strictly before the cutoffDate
 */
export function computeByokEligibility(
  accountCreatedAt: Date,
  cutoffEnabled: boolean,
  cutoffDate: Date | null,
): boolean {
  if (!cutoffEnabled) return false;
  if (cutoffDate === null) return false;
  return accountCreatedAt < cutoffDate;
}
