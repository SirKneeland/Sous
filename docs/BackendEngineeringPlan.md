# Sous — Backend Engineering Plan

This document is the master reference for the four-project billing and accounts
implementation. Every CC thread for this work should read this document before
starting. It defines scope, sequencing, architecture decisions, and the schema
that all projects share.

---

## The Four Projects

| Project | Name | CC Model | Touches iOS? | Touches Backend? |
|---|---|---|---|---|
| 1 | Backend Foundation | Opus | No | Yes |
| 2 | iOS Auth Integration | Opus | Yes | Yes (read only) |
| 3 | API Proxy + Instrumentation | Opus | Yes | Yes |
| 4 | Billing + Paywall | Opus | Yes | Yes |

All four projects must be complete before any TestFlight distribution.
No intermediate state is shipped to users.

**Status:** Project 1 (Backend Foundation) — code, schema, and tests COMPLETE in
`backend/`; remaining steps are operator-run external setup (Supabase project,
Railway deploy, Postman verification) per `backend/README.md`. Projects 2–4 not
started.

---

## Technology Decisions (final)

| Concern | Choice |
|---|---|
| Database + Auth | Supabase (managed Postgres) |
| API layer | Node.js + Hono |
| Hosting | Railway |
| iOS auth | Sign in with Apple → Sous session token |
| Subscription billing | StoreKit 2 + App Store Server API |
| Receipt validation | Server-side only (no client-side verifyReceipt) |
| SMS auth | Not in scope (V1) — Twilio if added later |

---

## Database Schema

### `users`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key, generated |
| `apple_sub` | text | Unique; Apple subject identifier; canonical user ID |
| `email` | text | Nullable; Apple relay or real email |
| `display_name` | text | Nullable; editable by user |
| `phone_number` | text | Nullable, unique when set; reserved for future phone auth |
| `account_created_at` | timestamptz | Set on first sign-in; BYOK eligibility anchor |
| `is_byok_eligible` | boolean | Set server-side when BYOK cutoff is configured |
| `referral_code` | text | Unique; auto-generated on account creation (e.g. SOUS-A7X2) |
| `referred_by_user_id` | uuid | Nullable FK → users.id |
| `is_deleted` | boolean | Soft delete; tombstone for re-registration check |
| `deleted_at` | timestamptz | Nullable |
| `abuse_flag` | boolean | Set by manual review |
| `abuse_flag_reason` | text | Nullable |

### `sessions` (auth)

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | FK → users.id |
| `token` | text | Opaque session token issued by Sous backend |
| `created_at` | timestamptz | |
| `expires_at` | timestamptz | |
| `revoked` | boolean | |

### `subscriptions`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | FK → users.id |
| `status` | text | `trialing`, `active`, `lapsed`, `cancelled` |
| `trial_started_at` | timestamptz | |
| `trial_ends_at` | timestamptz | Derived: trial_started_at + trial_duration_days |
| `trial_recipes_used` | integer | Incremented on each new recipe during trial |
| `current_period_start` | timestamptz | |
| `current_period_end` | timestamptz | |
| `apple_original_transaction_id` | text | Nullable; set when subscription is purchased |
| `apple_latest_receipt` | text | Nullable; updated via App Store Server Notifications |

### `usage_events`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | FK → users.id |
| `recipe_id` | text | Client-side recipe UUID |
| `request_type` | text | `text`, `image`, `voice` |
| `is_new_recipe` | boolean | Whether this request created a new recipe |
| `input_tokens` | integer | |
| `output_tokens` | integer | |
| `model` | text | e.g. `gpt-4o-mini` |
| `estimated_cost_usd` | numeric(10,6) | |
| `request_outcome` | text | `success`, `validation_failure`, `user_rejected_patch`, `error` |
| `voice_duration_seconds` | integer | Nullable; voice only |
| `voice_tts_characters` | integer | Nullable; voice only |
| `off_topic_flagged` | boolean | |
| `billing_period` | text | ISO month e.g. `2026-06` |
| `timestamp` | timestamptz | |

### `recipe_cap_counters`

| Column | Type | Notes |
|---|---|---|
| `user_id` | uuid | FK → users.id |
| `billing_period` | text | ISO month e.g. `2026-06` |
| `recipes_used` | integer | Incremented atomically on new recipe creation |

Composite primary key: (`user_id`, `billing_period`)

### `config`

| Column | Type | Notes |
|---|---|---|
| `key` | text | Primary key |
| `value` | text | JSON-serialized value |

Seed rows:

| Key | Default value |
|---|---|
| `trial_duration_days` | `14` |
| `trial_recipe_cap` | `14` |
| `paid_recipe_cap` | `100` |
| `byok_cutoff_enabled` | `false` |
| `byok_cutoff_date` | `null` |

### `memories`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | FK → users.id |
| `text` | text | Third-person memory string |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

### `preferences`

| Column | Type | Notes |
|---|---|---|
| `user_id` | uuid | Primary key, FK → users.id |
| `hard_avoids` | text[] | Array of ingredient/category strings |
| `serving_size` | integer | Nullable |
| `equipment` | text[] | |
| `custom_instructions` | text | Nullable |
| `personality_mode` | text | `minimal`, `normal`, `playful` |
| `updated_at` | timestamptz | |

### `deleted_accounts` (tombstone)

| Column | Type | Notes |
|---|---|---|
| `apple_sub` | text | Primary key |
| `deleted_at` | timestamptz | |

---

## API Endpoints

All endpoints are prefixed `/api/v1`. All require a `Authorization: Bearer <token>`
header except `/auth/apple`.

### Auth

| Method | Path | Description |
|---|---|---|
| POST | `/auth/apple` | Exchange Apple identity token for Sous session token |
| POST | `/auth/signout` | Revoke session token |
| DELETE | `/auth/account` | Delete account (tombstone + wipe) |

### Config

| Method | Path | Description |
|---|---|---|
| GET | `/config` | Fetch all remotely-configurable values for this user |

Returns trial duration, recipe caps, feature flags. Client caches this at launch.

### Usage + Entitlement

| Method | Path | Description |
|---|---|---|
| POST | `/usage/recipe` | Record a new recipe event; returns updated cap counter |
| POST | `/usage/request` | Record a non-recipe API request (chat, voice turn) |
| GET | `/usage/summary` | Current billing period usage for display in Settings |

### Proxy

| Method | Path | Description |
|---|---|---|
| POST | `/proxy/chat` | Proxy a chat completions request to OpenAI; records usage atomically |
| POST | `/proxy/tts` | Proxy a TTS request; records voice usage |

### Subscription

| Method | Path | Description |
|---|---|---|
| POST | `/subscription/validate` | Validate StoreKit receipt with Apple; update subscription record |
| GET | `/subscription/status` | Return current entitlement status |
| POST | `/subscription/notify` | App Store Server Notification webhook endpoint |

### Sync

| Method | Path | Description |
|---|---|---|
| GET | `/sync/preferences` | Fetch preferences |
| PUT | `/sync/preferences` | Update preferences |
| GET | `/sync/memories` | Fetch all memories |
| PUT | `/sync/memories` | Replace memory list |
| GET | `/sync/recipes` | Fetch recipe session list (metadata only) |
| PUT | `/sync/recipes/:id` | Upsert a recipe session |

### Referrals

| Method | Path | Description |
|---|---|---|
| GET | `/referral/code` | Return current user's referral code |
| POST | `/referral/apply` | Apply a referral code at signup (called during account creation) |

---

## Entitlement Logic

The backend computes entitlement status as follows, in order:

1. If `users.is_byok_eligible = true` → `byok` (full access, unmetered)
2. If `subscriptions.status = active` and current date within period → `subscriber`
3. If `subscriptions.status = trialing` and trial not expired by time or recipe count → `trialing`
4. If `subscriptions.status = lapsed` and within grace period (7 days) → `subscriber` (grace)
5. Otherwise → `soft_wall`

Entitlement is returned as part of `/config` and `/subscription/status`.
The iOS client treats entitlement as read-only and never computes it locally.

---

## BYOK Routing

BYOK users bypass the proxy entirely. The iOS client detects `entitlement = byok`
and routes OpenAI calls directly from the device using the locally stored API key,
exactly as today. No usage events are recorded server-side for BYOK requests.
Lightweight client-side telemetry (recipe count only) is sent separately.

---

## Off-Topic Detection

Implemented as middleware in the `/proxy/chat` endpoint.

- Input: user message text
- Method: keyword blocklist + optional embedding similarity check (V1: keyword only)
- If flagged: return 400 with `{ error: "off_topic" }` and a user-facing message
- Log the event to `usage_events.off_topic_flagged = true`
- Do NOT forward the message to OpenAI

---

## Abuse Thresholds (configurable via `config` table)

| Key | Default | Meaning |
|---|---|---|
| `abuse_recipes_per_day` | `20` | Flag if exceeded |
| `abuse_recipes_per_period` | `150` | Soft-lock if exceeded |
| `abuse_chat_per_recipe` | `200` | Flag if exceeded (monitoring only V1) |
| `abuse_off_topic_rate` | `0.30` | Flag if >30% of requests in a recipe are off-topic |

---

## Project 1 Definition of Done

- Supabase project created with full schema applied
- Railway project created with Hono API deployed
- `/auth/apple` endpoint verified via Postman
- `/config` endpoint returns seed config values
- All tables exist with correct columns and constraints
- `.env` files in place and gitignored
- `docs/BackendEngineeringPlan.md` committed to repo

## Project 2 Definition of Done

- iOS app requires sign-in on first launch
- Sign in with Apple creates a Sous account and stores session token in Keychain
- Preferences and memories sync to backend on change
- Account section in Settings shows status, email, delete option
- BYOK users see OG badge; app routes their requests directly (unchanged)
- `swift test` passes
- `CODEBASE.md`, `CLAUDE.md`, `UserStories.md`, `PRD.md`, `Milestones.md`, `kickoff.md` updated

## Project 3 Definition of Done

- All non-BYOK OpenAI calls route through `/proxy/chat` and `/proxy/tts`
- Every proxied call records a `usage_events` row
- `recipe_cap_counters` increments correctly on new recipe creation
- Internal dashboard shows live usage data
- Off-topic detection middleware is live
- `swift test` passes
- All docs updated

## Project 4 Definition of Done

- Paywall screen implemented with correct StoreKit 2 integration
- Trial starts on account creation; expires after 14 days or 14 recipes
- Voice mode blocked during trial
- Soft wall activates correctly at trial end
- Cap enforced at 100 recipes/month for paid subscribers
- Hard stop screen shows with "Message John" email button
- Whale UX message is correct
- Receipt validation via App Store Server API is working in sandbox
- App Store Server Notifications webhook is live
- `swift test` passes
- All docs updated

---

## Doc Update Checklist (end of every project)

- [ ] `CLAUDE.md` — update if new rules, tools, or patterns are introduced
- [ ] `CODEBASE.md` — add new files, modules, endpoints, and test targets
- [ ] `kickoff.md` — update current milestone state
- [ ] `docs/Milestones.md` — mark completed, update current/next
- [ ] `docs/PRD.md` — update Accounts & Billing section if behavior changed
- [ ] `docs/UserStories.md` — add acceptance criteria for new user-facing behaviors
- [ ] `/evals` — add eval cases if any system prompt was changed
