// In-memory Repo for integration tests. No Supabase, no network.
//
// It models just enough behavior to exercise the handlers: unique apple_sub,
// one subscription per user, session lookup/revoke, config map, tombstones.

import { randomUUID } from 'node:crypto';
import type { Repo } from '../db/repo.js';
import type {
  UserRow,
  SubscriptionRow,
  SessionRow,
  NewUser,
  NewSubscription,
  NewSession,
  PreferencesRow,
  PreferencesInput,
  MemoryRow,
  MemoryInput,
  UsageEventInput,
  UsageEventRow,
  RecipeCapCounterRow,
} from '../db/types.js';

export interface FakeRepoState {
  users: UserRow[];
  subscriptions: SubscriptionRow[];
  sessions: SessionRow[];
  deletedAccounts: { apple_sub: string; deleted_at: string }[];
  config: Record<string, string>;
  preferences: PreferencesRow[];
  memories: MemoryRow[];
  usageEvents: UsageEventRow[];
  recipeCapCounters: RecipeCapCounterRow[];
}

const DEFAULT_CONFIG: Record<string, string> = {
  trial_duration_days: '14',
  trial_recipe_cap: '14',
  paid_recipe_cap: '100',
  byok_cutoff_enabled: 'false',
  byok_cutoff_date: 'null',
  abuse_recipes_per_day: '20',
  abuse_recipes_per_period: '150',
  abuse_chat_per_recipe: '200',
  abuse_off_topic_rate: '0.30',
  off_topic_threshold: '0.8',
};

export function createFakeRepo(
  overrides: Partial<FakeRepoState> = {},
): { repo: Repo; state: FakeRepoState } {
  const state: FakeRepoState = {
    users: overrides.users ?? [],
    subscriptions: overrides.subscriptions ?? [],
    sessions: overrides.sessions ?? [],
    deletedAccounts: overrides.deletedAccounts ?? [],
    config: overrides.config ?? { ...DEFAULT_CONFIG },
    preferences: overrides.preferences ?? [],
    memories: overrides.memories ?? [],
    usageEvents: overrides.usageEvents ?? [],
    recipeCapCounters: overrides.recipeCapCounters ?? [],
  };

  const repo: Repo = {
    async getUserByAppleSub(appleSub) {
      return state.users.find((u) => u.apple_sub === appleSub) ?? null;
    },
    async getUserById(id) {
      return state.users.find((u) => u.id === id) ?? null;
    },
    async getUserByReferralCode(code) {
      return state.users.find((u) => u.referral_code === code) ?? null;
    },
    async createUser(input: NewUser) {
      const user: UserRow = {
        id: randomUUID(),
        apple_sub: input.appleSub,
        email: input.email,
        display_name: null,
        phone_number: null,
        account_created_at: new Date().toISOString(),
        is_byok_eligible: false,
        referral_code: input.referralCode,
        referred_by_user_id: input.referredByUserId,
        is_deleted: false,
        deleted_at: null,
        abuse_flag: false,
        abuse_flag_reason: null,
      };
      state.users.push(user);
      return user;
    },
    async softDeleteUser(userId, deletedAt) {
      const u = state.users.find((x) => x.id === userId);
      if (u) {
        u.is_deleted = true;
        u.deleted_at = deletedAt;
      }
    },
    async updateDisplayName(userId, displayName) {
      const u = state.users.find((x) => x.id === userId);
      if (u) u.display_name = displayName;
    },
    async getDeletedAccount(appleSub) {
      const row = state.deletedAccounts.find((d) => d.apple_sub === appleSub);
      return row ? { apple_sub: row.apple_sub } : null;
    },
    async insertDeletedAccount(appleSub, deletedAt) {
      const existing = state.deletedAccounts.find((d) => d.apple_sub === appleSub);
      if (existing) existing.deleted_at = deletedAt;
      else state.deletedAccounts.push({ apple_sub: appleSub, deleted_at: deletedAt });
    },
    async getSubscriptionByUserId(userId) {
      return state.subscriptions.find((s) => s.user_id === userId) ?? null;
    },
    async createSubscription(input: NewSubscription) {
      const sub: SubscriptionRow = {
        id: randomUUID(),
        user_id: input.userId,
        status: input.status,
        trial_started_at: input.trialStartedAt,
        trial_ends_at: input.trialEndsAt,
        trial_recipes_used: 0,
        current_period_start: null,
        current_period_end: null,
        apple_original_transaction_id: null,
        apple_latest_receipt: null,
      };
      state.subscriptions.push(sub);
      return sub;
    },
    async getSubscriptionByOriginalTransactionId(originalTransactionId) {
      return (
        state.subscriptions.find(
          (s) => s.apple_original_transaction_id === originalTransactionId,
        ) ?? null
      );
    },
    async updateSubscriptionFromApple(userId, input) {
      let sub = state.subscriptions.find((s) => s.user_id === userId);
      if (!sub) {
        sub = {
          id: randomUUID(),
          user_id: userId,
          status: input.status,
          trial_started_at: null,
          trial_ends_at: null,
          trial_recipes_used: 0,
          current_period_start: null,
          current_period_end: null,
          apple_original_transaction_id: null,
          apple_latest_receipt: null,
        };
        state.subscriptions.push(sub);
      }
      sub.status = input.status;
      sub.apple_original_transaction_id = input.appleOriginalTransactionId;
      sub.current_period_start = input.currentPeriodStart;
      sub.current_period_end = input.currentPeriodEnd;
      if (input.appleLatestReceipt !== undefined) {
        sub.apple_latest_receipt = input.appleLatestReceipt;
      }
      return sub;
    },
    async updateSubscriptionLifecycle(subscriptionId, input) {
      const sub = state.subscriptions.find((s) => s.id === subscriptionId);
      if (!sub) return;
      sub.status = input.status;
      if (input.currentPeriodEnd !== undefined) sub.current_period_end = input.currentPeriodEnd;
      if (input.appleLatestReceipt !== undefined) sub.apple_latest_receipt = input.appleLatestReceipt;
    },
    async insertSession(input: NewSession) {
      const session: SessionRow = {
        id: input.id,
        user_id: input.userId,
        token: input.token,
        created_at: new Date().toISOString(),
        expires_at: input.expiresAt,
        revoked: false,
      };
      state.sessions.push(session);
      return session;
    },
    async getSessionByToken(token) {
      return state.sessions.find((s) => s.token === token) ?? null;
    },
    async revokeSession(token) {
      const s = state.sessions.find((x) => x.token === token);
      if (s) s.revoked = true;
    },
    async revokeAllSessionsForUser(userId) {
      for (const s of state.sessions) if (s.user_id === userId) s.revoked = true;
    },
    async getConfigAll() {
      return { ...state.config };
    },
    async getPreferences(userId) {
      return state.preferences.find((p) => p.user_id === userId) ?? null;
    },
    async upsertPreferences(userId, input) {
      const now = new Date().toISOString();
      const existing = state.preferences.find((p) => p.user_id === userId);
      const row: PreferencesRow = {
        user_id: userId,
        hard_avoids: input.hardAvoids,
        serving_size: input.servingSize,
        equipment: input.equipment,
        custom_instructions: input.customInstructions,
        personality_mode: input.personalityMode,
        updated_at: now,
      };
      if (existing) Object.assign(existing, row);
      else state.preferences.push(row);
      return row;
    },
    async getMemories(userId) {
      return state.memories
        .filter((m) => m.user_id === userId)
        .sort((a, b) => a.created_at.localeCompare(b.created_at));
    },
    async replaceMemories(userId, items) {
      // Full replace: drop this user's rows, then insert the supplied list.
      state.memories = state.memories.filter((m) => m.user_id !== userId);
      const now = new Date().toISOString();
      const inserted: MemoryRow[] = items.map((item) => ({
        id: item.id ?? randomUUID(),
        user_id: userId,
        text: item.text,
        created_at: item.createdAt ?? now,
        updated_at: now,
      }));
      state.memories.push(...inserted);
      return inserted;
    },

    // ---- usage + instrumentation ----

    async insertUsageEvent(input: UsageEventInput) {
      state.usageEvents.push({
        id: randomUUID(),
        user_id: input.userId,
        recipe_id: input.recipeId,
        request_type: input.requestType,
        is_new_recipe: input.isNewRecipe,
        input_tokens: input.inputTokens,
        output_tokens: input.outputTokens,
        model: input.model,
        estimated_cost_usd: input.estimatedCostUsd,
        request_outcome: input.requestOutcome,
        voice_duration_seconds: input.voiceDurationSeconds ?? null,
        voice_tts_characters: input.voiceTtsCharacters ?? null,
        off_topic_flagged: input.offTopicFlagged,
        billing_period: input.billingPeriod,
        timestamp: new Date().toISOString(),
      });
    },

    async incrementRecipeCapCounter(userId, billingPeriod) {
      const existing = state.recipeCapCounters.find(
        (r) => r.user_id === userId && r.billing_period === billingPeriod,
      );
      if (existing) {
        existing.recipes_used += 1;
        return existing.recipes_used;
      }
      state.recipeCapCounters.push({
        user_id: userId,
        billing_period: billingPeriod,
        recipes_used: 1,
      });
      return 1;
    },

    async getRecipeCapCount(userId, billingPeriod) {
      const existing = state.recipeCapCounters.find(
        (r) => r.user_id === userId && r.billing_period === billingPeriod,
      );
      return existing?.recipes_used ?? 0;
    },

    async incrementTrialRecipesUsed(userId) {
      const sub = state.subscriptions.find((s) => s.user_id === userId);
      if (!sub) return null;
      sub.trial_recipes_used += 1;
      return sub.trial_recipes_used;
    },

    // ---- abuse detection ----

    async setAbuseFlag(userId, reason) {
      const u = state.users.find((x) => x.id === userId);
      if (u) {
        u.abuse_flag = true;
        u.abuse_flag_reason = reason;
      }
    },

    async countNewRecipesSince(userId, sinceIso) {
      return state.usageEvents.filter(
        (e) => e.user_id === userId && e.is_new_recipe && e.timestamp >= sinceIso,
      ).length;
    },

    async countEventsForRecipe(userId, recipeId) {
      return state.usageEvents.filter(
        (e) => e.user_id === userId && e.recipe_id === recipeId,
      ).length;
    },

    // ---- admin dashboard aggregates ----

    async listAllUsers() {
      return [...state.users];
    },
    async listAllSubscriptions() {
      return [...state.subscriptions];
    },
    async getUsageEventsForPeriod(billingPeriod) {
      return state.usageEvents.filter((e) => e.billing_period === billingPeriod);
    },
    async getRecipeCapCountersForPeriod(billingPeriod) {
      return state.recipeCapCounters.filter((r) => r.billing_period === billingPeriod);
    },
  };

  return { repo, state };
}
