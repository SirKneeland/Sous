// Row shapes mirroring the SQL schema (backend/db/schema.sql). Only the columns
// the API reads/writes in Project 1 are typed precisely; the rest are present
// for completeness.

export interface UserRow {
  id: string;
  apple_sub: string;
  email: string | null;
  display_name: string | null;
  phone_number: string | null;
  account_created_at: string;
  is_byok_eligible: boolean;
  referral_code: string;
  referred_by_user_id: string | null;
  is_deleted: boolean;
  deleted_at: string | null;
  abuse_flag: boolean;
  abuse_flag_reason: string | null;
}

export type SubscriptionStatus =
  | 'trialing'
  | 'active'
  | 'lapsed'
  | 'cancelled'
  | 'soft_wall';

export interface SubscriptionRow {
  id: string;
  user_id: string;
  status: SubscriptionStatus;
  trial_started_at: string | null;
  trial_ends_at: string | null;
  trial_recipes_used: number;
  current_period_start: string | null;
  current_period_end: string | null;
  apple_original_transaction_id: string | null;
  apple_latest_receipt: string | null;
}

export interface SessionRow {
  id: string;
  user_id: string;
  token: string;
  created_at: string;
  expires_at: string;
  revoked: boolean;
}

export interface NewUser {
  appleSub: string;
  email: string | null;
  referralCode: string;
  referredByUserId: string | null;
}

export interface NewSubscription {
  userId: string;
  status: SubscriptionStatus;
  trialStartedAt: string | null;
  trialEndsAt: string | null;
}

export interface NewSession {
  /** Pre-generated so it can be embedded in the signed token before insert. */
  id: string;
  userId: string;
  token: string;
  expiresAt: string;
}
