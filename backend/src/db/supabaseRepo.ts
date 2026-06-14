// Supabase-backed implementation of Repo.

import type { SupabaseClient } from '@supabase/supabase-js';
import type { Repo } from './repo.js';
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
} from './types.js';

/** Supabase returns a PostgREST error with code PGRST116 when .single() finds no row. */
function isNoRows(error: { code?: string } | null): boolean {
  return error?.code === 'PGRST116';
}

export function createSupabaseRepo(db: SupabaseClient): Repo {
  return {
    async getUserByAppleSub(appleSub) {
      const { data, error } = await db
        .from('users')
        .select('*')
        .eq('apple_sub', appleSub)
        .single();
      if (error && !isNoRows(error)) throw error;
      return (data as UserRow) ?? null;
    },

    async getUserById(id) {
      const { data, error } = await db
        .from('users')
        .select('*')
        .eq('id', id)
        .single();
      if (error && !isNoRows(error)) throw error;
      return (data as UserRow) ?? null;
    },

    async getUserByReferralCode(code) {
      const { data, error } = await db
        .from('users')
        .select('*')
        .eq('referral_code', code)
        .single();
      if (error && !isNoRows(error)) throw error;
      return (data as UserRow) ?? null;
    },

    async createUser(input: NewUser) {
      const { data, error } = await db
        .from('users')
        .insert({
          apple_sub: input.appleSub,
          email: input.email,
          referral_code: input.referralCode,
          referred_by_user_id: input.referredByUserId,
        })
        .select('*')
        .single();
      if (error) throw error;
      return data as UserRow;
    },

    async softDeleteUser(userId, deletedAt) {
      const { error } = await db
        .from('users')
        .update({ is_deleted: true, deleted_at: deletedAt })
        .eq('id', userId);
      if (error) throw error;
    },

    async updateDisplayName(userId, displayName) {
      const { error } = await db
        .from('users')
        .update({ display_name: displayName })
        .eq('id', userId);
      if (error) throw error;
    },

    async getDeletedAccount(appleSub) {
      const { data, error } = await db
        .from('deleted_accounts')
        .select('apple_sub')
        .eq('apple_sub', appleSub)
        .single();
      if (error && !isNoRows(error)) throw error;
      return (data as { apple_sub: string }) ?? null;
    },

    async insertDeletedAccount(appleSub, deletedAt) {
      const { error } = await db
        .from('deleted_accounts')
        .upsert({ apple_sub: appleSub, deleted_at: deletedAt });
      if (error) throw error;
    },

    async getSubscriptionByUserId(userId) {
      const { data, error } = await db
        .from('subscriptions')
        .select('*')
        .eq('user_id', userId)
        .single();
      if (error && !isNoRows(error)) throw error;
      return (data as SubscriptionRow) ?? null;
    },

    async createSubscription(input: NewSubscription) {
      const { data, error } = await db
        .from('subscriptions')
        .insert({
          user_id: input.userId,
          status: input.status,
          trial_started_at: input.trialStartedAt,
          trial_ends_at: input.trialEndsAt,
        })
        .select('*')
        .single();
      if (error) throw error;
      return data as SubscriptionRow;
    },

    async insertSession(input: NewSession) {
      const { data, error } = await db
        .from('sessions')
        .insert({
          id: input.id,
          user_id: input.userId,
          token: input.token,
          expires_at: input.expiresAt,
        })
        .select('*')
        .single();
      if (error) throw error;
      return data as SessionRow;
    },

    async getSessionByToken(token) {
      const { data, error } = await db
        .from('sessions')
        .select('*')
        .eq('token', token)
        .single();
      if (error && !isNoRows(error)) throw error;
      return (data as SessionRow) ?? null;
    },

    async revokeSession(token) {
      const { error } = await db
        .from('sessions')
        .update({ revoked: true })
        .eq('token', token);
      if (error) throw error;
    },

    async revokeAllSessionsForUser(userId) {
      const { error } = await db
        .from('sessions')
        .update({ revoked: true })
        .eq('user_id', userId);
      if (error) throw error;
    },

    async getConfigAll() {
      const { data, error } = await db.from('config').select('key, value');
      if (error) throw error;
      const out: Record<string, string> = {};
      for (const row of (data as { key: string; value: string }[]) ?? []) {
        out[row.key] = row.value;
      }
      return out;
    },

    async getPreferences(userId) {
      const { data, error } = await db
        .from('preferences')
        .select('*')
        .eq('user_id', userId)
        .single();
      if (error && !isNoRows(error)) throw error;
      return (data as PreferencesRow) ?? null;
    },

    async upsertPreferences(userId, input: PreferencesInput) {
      const { data, error } = await db
        .from('preferences')
        .upsert({
          user_id: userId,
          hard_avoids: input.hardAvoids,
          serving_size: input.servingSize,
          equipment: input.equipment,
          custom_instructions: input.customInstructions,
          personality_mode: input.personalityMode,
          updated_at: new Date().toISOString(),
        })
        .select('*')
        .single();
      if (error) throw error;
      return data as PreferencesRow;
    },

    async getMemories(userId) {
      const { data, error } = await db
        .from('memories')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: true });
      if (error) throw error;
      return (data as MemoryRow[]) ?? [];
    },

    async replaceMemories(userId, items: MemoryInput[]) {
      // Full-list replace: delete the user's existing rows, then insert the new
      // set. Not wrapped in a transaction (Supabase JS has no multi-statement tx);
      // acceptable because memory sync is last-write-wins and idempotent.
      const { error: delError } = await db
        .from('memories')
        .delete()
        .eq('user_id', userId);
      if (delError) throw delError;

      if (items.length === 0) return [];

      const now = new Date().toISOString();
      const rows = items.map((item) => ({
        ...(item.id ? { id: item.id } : {}),
        user_id: userId,
        text: item.text,
        created_at: item.createdAt ?? now,
        updated_at: now,
      }));
      const { data, error } = await db.from('memories').insert(rows).select('*');
      if (error) throw error;
      return (data as MemoryRow[]) ?? [];
    },

    // ---- usage + instrumentation ----

    async insertUsageEvent(input: UsageEventInput) {
      const { error } = await db.from('usage_events').insert({
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
      });
      if (error) throw error;
    },

    async incrementRecipeCapCounter(userId, billingPeriod) {
      const { data, error } = await db.rpc('increment_recipe_cap_counter', {
        p_user_id: userId,
        p_billing_period: billingPeriod,
      });
      if (error) throw error;
      return (data as number) ?? 0;
    },

    async getRecipeCapCount(userId, billingPeriod) {
      const { data, error } = await db
        .from('recipe_cap_counters')
        .select('recipes_used')
        .eq('user_id', userId)
        .eq('billing_period', billingPeriod)
        .single();
      if (error && !isNoRows(error)) throw error;
      return (data as { recipes_used: number } | null)?.recipes_used ?? 0;
    },

    async incrementTrialRecipesUsed(userId) {
      const { data, error } = await db.rpc('increment_trial_recipes_used', {
        p_user_id: userId,
      });
      if (error) throw error;
      return (data as number | null) ?? null;
    },

    // ---- abuse detection ----

    async setAbuseFlag(userId, reason) {
      const { error } = await db
        .from('users')
        .update({ abuse_flag: true, abuse_flag_reason: reason })
        .eq('id', userId);
      if (error) throw error;
    },

    async countNewRecipesSince(userId, sinceIso) {
      const { count, error } = await db
        .from('usage_events')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('is_new_recipe', true)
        .gte('timestamp', sinceIso);
      if (error) throw error;
      return count ?? 0;
    },

    async countEventsForRecipe(userId, recipeId) {
      const { count, error } = await db
        .from('usage_events')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('recipe_id', recipeId);
      if (error) throw error;
      return count ?? 0;
    },

    // ---- admin dashboard aggregates ----

    async listAllUsers() {
      const { data, error } = await db.from('users').select('*');
      if (error) throw error;
      return (data as UserRow[]) ?? [];
    },

    async listAllSubscriptions() {
      const { data, error } = await db.from('subscriptions').select('*');
      if (error) throw error;
      return (data as SubscriptionRow[]) ?? [];
    },

    async getUsageEventsForPeriod(billingPeriod) {
      const { data, error } = await db
        .from('usage_events')
        .select('*')
        .eq('billing_period', billingPeriod);
      if (error) throw error;
      return (data as UsageEventRow[]) ?? [];
    },

    async getRecipeCapCountersForPeriod(billingPeriod) {
      const { data, error } = await db
        .from('recipe_cap_counters')
        .select('*')
        .eq('billing_period', billingPeriod);
      if (error) throw error;
      return (data as RecipeCapCounterRow[]) ?? [];
    },
  };
}
