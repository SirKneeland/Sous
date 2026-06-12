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
} from '../db/types.js';

export interface FakeRepoState {
  users: UserRow[];
  subscriptions: SubscriptionRow[];
  sessions: SessionRow[];
  deletedAccounts: { apple_sub: string; deleted_at: string }[];
  config: Record<string, string>;
}

const DEFAULT_CONFIG: Record<string, string> = {
  trial_duration_days: '14',
  trial_recipe_cap: '14',
  paid_recipe_cap: '100',
  byok_cutoff_enabled: 'false',
  byok_cutoff_date: 'null',
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
  };

  return { repo, state };
}
