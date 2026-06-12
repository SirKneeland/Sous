// Entitlement computation — the single source of truth for "what access does
// this user have right now". The iOS client treats this as read-only and never
// computes it locally (see docs/BackendEngineeringPlan.md → Entitlement Logic).
//
// The five entitlement states:
//   byok       — bring-your-own-key user, full unmetered access, bypasses proxy
//   subscriber — active paid subscription within its period
//   trialing   — in trial, not expired by time OR by recipe count
//   grace      — subscription lapsed but within the 7-day grace window (treated
//                as subscriber-level access; surfaced distinctly so the client
//                can nudge the user to fix billing)
//   soft_wall  — no access; show the paywall / soft wall
//
// Order of evaluation matters and follows the engineering plan exactly.

export type Entitlement =
  | 'byok'
  | 'subscriber'
  | 'trialing'
  | 'grace'
  | 'soft_wall';

export const GRACE_PERIOD_DAYS = 7;

export interface UserRow {
  is_byok_eligible: boolean;
}

export interface SubscriptionRow {
  status: 'trialing' | 'active' | 'lapsed' | 'cancelled' | 'soft_wall';
  trial_ends_at: string | null;
  trial_recipes_used: number;
  current_period_start: string | null;
  current_period_end: string | null;
}

/** Parsed config values relevant to entitlement. */
export interface EntitlementConfig {
  trialRecipeCap: number;
}

export interface EntitlementResult {
  status: Entitlement;
  /** Human-readable reason, useful for debugging and Settings display. */
  reason: string;
  /** True when the user is allowed to make metered requests right now. */
  hasAccess: boolean;
}

function daysFromNow(iso: string | null, days: number): Date | null {
  if (!iso) return null;
  return new Date(new Date(iso).getTime() + days * 24 * 60 * 60 * 1000);
}

/**
 * Compute the current entitlement for a user.
 *
 * @param user         the users row (only is_byok_eligible is consulted)
 * @param subscription the user's subscription row, or null if none exists
 * @param config       parsed config (trial recipe cap)
 * @param now          injectable clock for testing
 */
export function computeEntitlement(
  user: UserRow,
  subscription: SubscriptionRow | null,
  config: EntitlementConfig,
  now: Date = new Date(),
): EntitlementResult {
  // 1. BYOK eligibility trumps everything.
  if (user.is_byok_eligible) {
    return { status: 'byok', reason: 'User is BYOK-eligible', hasAccess: true };
  }

  // No subscription row at all → soft wall.
  if (!subscription) {
    return {
      status: 'soft_wall',
      reason: 'No subscription record',
      hasAccess: false,
    };
  }

  const sub = subscription;

  // 2. Active paid subscription within its current period.
  if (sub.status === 'active') {
    const end = sub.current_period_end ? new Date(sub.current_period_end) : null;
    if (end && now <= end) {
      return {
        status: 'subscriber',
        reason: 'Active subscription within current period',
        hasAccess: true,
      };
    }
    // Active but period elapsed: fall through to grace/soft_wall handling below
    // by treating it like a lapse.
  }

  // 3. Trial that has not expired by time OR by recipe count.
  if (sub.status === 'trialing') {
    const trialEnds = sub.trial_ends_at ? new Date(sub.trial_ends_at) : null;
    const withinTime = trialEnds != null && now < trialEnds;
    const withinRecipes = sub.trial_recipes_used < config.trialRecipeCap;
    if (withinTime && withinRecipes) {
      return {
        status: 'trialing',
        reason: 'Trial active (time and recipe count remaining)',
        hasAccess: true,
      };
    }
    return {
      status: 'soft_wall',
      reason: !withinTime
        ? 'Trial expired by time'
        : 'Trial expired by recipe count',
      hasAccess: false,
    };
  }

  // 4. Lapsed subscription within the 7-day grace window.
  if (sub.status === 'lapsed') {
    const graceEnds = daysFromNow(sub.current_period_end, GRACE_PERIOD_DAYS);
    if (graceEnds && now <= graceEnds) {
      return {
        status: 'grace',
        reason: 'Subscription lapsed but within 7-day grace period',
        hasAccess: true,
      };
    }
  }

  // 5. Everything else (cancelled, soft_wall, expired-active, post-grace lapse).
  return {
    status: 'soft_wall',
    reason: `No active entitlement (subscription status: ${sub.status})`,
    hasAccess: false,
  };
}
