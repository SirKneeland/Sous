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
  NewSession,
} from './types.js';

export interface Repo {
  // users
  getUserByAppleSub(appleSub: string): Promise<UserRow | null>;
  getUserById(id: string): Promise<UserRow | null>;
  getUserByReferralCode(code: string): Promise<UserRow | null>;
  createUser(input: NewUser): Promise<UserRow>;
  softDeleteUser(userId: string, deletedAt: string): Promise<void>;

  // tombstone
  getDeletedAccount(appleSub: string): Promise<{ apple_sub: string } | null>;
  insertDeletedAccount(appleSub: string, deletedAt: string): Promise<void>;

  // subscriptions
  getSubscriptionByUserId(userId: string): Promise<SubscriptionRow | null>;
  createSubscription(input: NewSubscription): Promise<SubscriptionRow>;

  // sessions
  insertSession(input: NewSession): Promise<SessionRow>;
  getSessionByToken(token: string): Promise<SessionRow | null>;
  revokeSession(token: string): Promise<void>;
  revokeAllSessionsForUser(userId: string): Promise<void>;

  // config
  getConfigAll(): Promise<Record<string, string>>;
}
