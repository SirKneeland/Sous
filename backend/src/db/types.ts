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

/** Fields written when a StoreKit purchase/restore is validated (Project 4). */
export interface AppleSubscriptionUpdate {
  status: SubscriptionStatus;
  appleOriginalTransactionId: string;
  currentPeriodStart: string | null;
  currentPeriodEnd: string | null;
  appleLatestReceipt?: string | null;
}

/** Fields written on an App Store Server Notification lifecycle event (Project 4). */
export interface SubscriptionLifecycleUpdate {
  status: SubscriptionStatus;
  currentPeriodEnd?: string | null;
  appleLatestReceipt?: string | null;
}

export interface NewSession {
  /** Pre-generated so it can be embedded in the signed token before insert. */
  id: string;
  userId: string;
  token: string;
  expiresAt: string;
}

// ---------------------------------------------------------------------------
// Sync: preferences + memories (Project 2)
// ---------------------------------------------------------------------------

export interface PreferencesRow {
  user_id: string;
  hard_avoids: string[];
  serving_size: number | null;
  equipment: string[];
  custom_instructions: string | null;
  personality_mode: string | null;
  updated_at: string;
}

/** Caller-supplied preferences for an upsert (snake_case-free, mapped in the repo). */
export interface PreferencesInput {
  hardAvoids: string[];
  servingSize: number | null;
  equipment: string[];
  customInstructions: string | null;
  personalityMode: string | null;
}

export interface MemoryRow {
  id: string;
  user_id: string;
  text: string;
  created_at: string;
  updated_at: string;
}

/** One memory in a full-list replace. `id`/`createdAt` are preserved when supplied. */
export interface MemoryInput {
  id?: string;
  text: string;
  createdAt?: string;
}

// ---------------------------------------------------------------------------
// Usage + instrumentation (Project 3)
// ---------------------------------------------------------------------------

export type RequestType = 'text' | 'image' | 'voice';
export type RequestOutcome =
  | 'success'
  | 'validation_failure'
  | 'user_rejected_patch'
  | 'error';

export interface UsageEventRow {
  id: string;
  user_id: string;
  recipe_id: string | null;
  request_type: RequestType | null;
  is_new_recipe: boolean;
  input_tokens: number | null;
  output_tokens: number | null;
  model: string | null;
  estimated_cost_usd: number | null;
  request_outcome: RequestOutcome | null;
  voice_duration_seconds: number | null;
  voice_tts_characters: number | null;
  off_topic_flagged: boolean;
  billing_period: string | null;
  timestamp: string;
}

/** Fields the API supplies when recording a usage event. */
export interface UsageEventInput {
  userId: string;
  recipeId: string | null;
  requestType: RequestType | null;
  isNewRecipe: boolean;
  inputTokens: number | null;
  outputTokens: number | null;
  model: string | null;
  estimatedCostUsd: number | null;
  requestOutcome: RequestOutcome | null;
  voiceDurationSeconds?: number | null;
  voiceTtsCharacters?: number | null;
  offTopicFlagged: boolean;
  billingPeriod: string | null;
}

export interface RecipeCapCounterRow {
  user_id: string;
  billing_period: string;
  recipes_used: number;
}
