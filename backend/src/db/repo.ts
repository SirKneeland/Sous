// Repo — the data-access boundary the route handlers depend on.
//
// Handlers never touch the Supabase client directly; they call these methods.
// This keeps the chained Supabase query-builder out of the handlers and lets the
// integration tests inject a simple in-memory fake (see src/test/fakeRepo.ts).

import type {
  UserRow,
  SubscriptionRow,
  SessionRow,
  NewUser,
  NewSubscription,
  AppleSubscriptionUpdate,
  SubscriptionLifecycleUpdate,
  NewSession,
  PreferencesRow,
  PreferencesInput,
  MemoryRow,
  MemoryInput,
  UsageEventInput,
  UsageEventRow,
  RecipeCapCounterRow,
} from './types.js';

export interface Repo {
  // users
  getUserByAppleSub(appleSub: string): Promise<UserRow | null>;
  getUserById(id: string): Promise<UserRow | null>;
  getUserByReferralCode(code: string): Promise<UserRow | null>;
  createUser(input: NewUser): Promise<UserRow>;
  updateDisplayName(userId: string, displayName: string | null): Promise<void>;
  setByokEligible(userId: string, eligible: boolean): Promise<void>;

  // tombstone — `appleSubHash` is the HMAC of the apple_sub (see lib/secrets.hashAppleSub),
  // never the raw value.
  getDeletedAccount(appleSubHash: string): Promise<{ apple_sub: string } | null>;
  /**
   * Atomically delete an account: write the hashed tombstone, scrub the user row's
   * PII (email/display_name/phone_number/apple_sub → null) and mark it deleted,
   * hard-delete the user's preferences + memories, and revoke all their sessions —
   * all in one transaction. Subscriptions are intentionally left untouched.
   * `appleSubHash` must already be hashed by the caller.
   */
  purgeAccount(userId: string, appleSubHash: string, deletedAt: string): Promise<void>;

  // subscriptions
  getSubscriptionByUserId(userId: string): Promise<SubscriptionRow | null>;
  createSubscription(input: NewSubscription): Promise<SubscriptionRow>;
  /** Look up a subscription by Apple's original transaction id (notify webhook). */
  getSubscriptionByOriginalTransactionId(originalTransactionId: string): Promise<SubscriptionRow | null>;
  /** Upsert the user's subscription from a validated StoreKit purchase. */
  updateSubscriptionFromApple(userId: string, input: AppleSubscriptionUpdate): Promise<SubscriptionRow>;
  /** Apply an App Store notification lifecycle change to a subscription row. */
  updateSubscriptionLifecycle(subscriptionId: string, input: SubscriptionLifecycleUpdate): Promise<void>;

  // sessions
  insertSession(input: NewSession): Promise<SessionRow>;
  getSessionByToken(token: string): Promise<SessionRow | null>;
  revokeSession(token: string): Promise<void>;
  revokeAllSessionsForUser(userId: string): Promise<void>;

  // config
  getConfigAll(): Promise<Record<string, string>>;

  // sync: preferences (one row per user)
  getPreferences(userId: string): Promise<PreferencesRow | null>;
  upsertPreferences(userId: string, input: PreferencesInput): Promise<PreferencesRow>;

  // sync: memories (full-list replace)
  getMemories(userId: string): Promise<MemoryRow[]>;
  replaceMemories(userId: string, items: MemoryInput[]): Promise<MemoryRow[]>;

  // usage + instrumentation (Project 3)
  insertUsageEvent(input: UsageEventInput): Promise<void>;
  /** Atomically +1 the recipe_cap_counters row for (user, period); returns new count. */
  incrementRecipeCapCounter(userId: string, billingPeriod: string): Promise<number>;
  /** Current recipe_cap_counters value for (user, period); 0 if no row yet. */
  getRecipeCapCount(userId: string, billingPeriod: string): Promise<number>;
  /** Atomically +1 subscriptions.trial_recipes_used; returns new value or null if no sub. */
  incrementTrialRecipesUsed(userId: string): Promise<number | null>;

  // abuse detection
  setAbuseFlag(userId: string, reason: string): Promise<void>;
  /** New-recipe usage events for a user at/after the given ISO timestamp. */
  countNewRecipesSince(userId: string, sinceIso: string): Promise<number>;
  /** Total usage events recorded against one recipe for a user. */
  countEventsForRecipe(userId: string, recipeId: string): Promise<number>;

  // admin dashboard aggregates
  listAllUsers(): Promise<UserRow[]>;
  listAllSubscriptions(): Promise<SubscriptionRow[]>;
  getUsageEventsForPeriod(billingPeriod: string): Promise<UsageEventRow[]>;
  getRecipeCapCountersForPeriod(billingPeriod: string): Promise<RecipeCapCounterRow[]>;
}
