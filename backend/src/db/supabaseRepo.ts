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
  };
}
