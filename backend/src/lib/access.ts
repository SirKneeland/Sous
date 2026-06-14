// Shared helper: resolve a user's current entitlement + the raw config the
// proxy/usage routes need. Centralizes the getUser → getSubscription → config →
// computeEntitlement sequence so it stays consistent across endpoints.

import type { AppDeps } from '../types.js';
import type { UserRow, SubscriptionRow } from '../db/types.js';
import { computeEntitlement, type EntitlementResult } from './entitlement.js';
import { entitlementConfigFrom } from './config.js';

export interface ResolvedAccess {
  user: UserRow;
  subscription: SubscriptionRow | null;
  rawConfig: Record<string, string>;
  entitlement: EntitlementResult;
}

/** Returns null if the user does not exist. */
export async function resolveAccess(
  deps: AppDeps,
  userId: string,
): Promise<ResolvedAccess | null> {
  const user = await deps.repo.getUserById(userId);
  if (!user) return null;
  const subscription = await deps.repo.getSubscriptionByUserId(userId);
  const rawConfig = await deps.repo.getConfigAll();
  const entitlement = computeEntitlement(
    { is_byok_eligible: user.is_byok_eligible },
    subscription,
    entitlementConfigFrom(rawConfig),
    deps.now(),
  );
  return { user, subscription, rawConfig, entitlement };
}
