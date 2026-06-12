-- Sous backend — full schema migration (Project 1: Backend Foundation)
--
-- HOW TO RUN:
--   Paste this entire file into the Supabase SQL editor and click "Run".
--   It is idempotent-ish: it uses CREATE TABLE IF NOT EXISTS so re-running is safe,
--   but it will NOT alter columns on tables that already exist. For a clean slate
--   on a brand-new project, just run it once.
--
-- Source of truth for this schema: docs/BackendEngineeringPlan.md
--
-- NOTE (flagged deviation): the engineering plan enumerates subscriptions.status as
-- (trialing, active, lapsed, cancelled). The Project 1 kickoff additionally requires
-- re-registered (previously-deleted) users to be stored with status = 'soft_wall'.
-- The CHECK constraint below therefore also permits 'soft_wall'. See entitlement.ts.

-- gen_random_uuid() is available in Supabase by default (pgcrypto).
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id                  uuid primary key default gen_random_uuid(),
  apple_sub           text unique not null,
  email               text,
  display_name        text,
  phone_number        text unique,
  account_created_at  timestamptz not null default now(),
  is_byok_eligible    boolean not null default false,
  referral_code       text unique not null,
  referred_by_user_id uuid references public.users(id),
  is_deleted          boolean not null default false,
  deleted_at          timestamptz,
  abuse_flag          boolean not null default false,
  abuse_flag_reason   text
);

-- ---------------------------------------------------------------------------
-- sessions (auth)
-- ---------------------------------------------------------------------------
create table if not exists public.sessions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id),
  token      text unique not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked    boolean not null default false
);

create index if not exists sessions_token_idx on public.sessions (token);
create index if not exists sessions_user_id_idx on public.sessions (user_id);

-- ---------------------------------------------------------------------------
-- subscriptions
-- ---------------------------------------------------------------------------
create table if not exists public.subscriptions (
  id                            uuid primary key default gen_random_uuid(),
  user_id                       uuid not null references public.users(id),
  status                        text not null
                                  check (status in ('trialing','active','lapsed','cancelled','soft_wall')),
  trial_started_at              timestamptz,
  trial_ends_at                 timestamptz,
  trial_recipes_used            integer not null default 0,
  current_period_start          timestamptz,
  current_period_end            timestamptz,
  apple_original_transaction_id text,
  apple_latest_receipt          text
);

create index if not exists subscriptions_user_id_idx on public.subscriptions (user_id);

-- ---------------------------------------------------------------------------
-- usage_events
-- ---------------------------------------------------------------------------
create table if not exists public.usage_events (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references public.users(id),
  recipe_id              text,
  request_type           text check (request_type in ('text','image','voice')),
  is_new_recipe          boolean not null default false,
  input_tokens           integer,
  output_tokens          integer,
  model                  text,
  estimated_cost_usd     numeric(10,6),
  request_outcome        text check (request_outcome in ('success','validation_failure','user_rejected_patch','error')),
  voice_duration_seconds integer,
  voice_tts_characters   integer,
  off_topic_flagged      boolean not null default false,
  billing_period         text,
  timestamp              timestamptz not null default now()
);

create index if not exists usage_events_user_period_idx on public.usage_events (user_id, billing_period);

-- ---------------------------------------------------------------------------
-- recipe_cap_counters
-- ---------------------------------------------------------------------------
create table if not exists public.recipe_cap_counters (
  user_id        uuid not null references public.users(id),
  billing_period text not null,
  recipes_used   integer not null default 0,
  primary key (user_id, billing_period)
);

-- ---------------------------------------------------------------------------
-- config (remote config / feature flags). value is a JSON-serialized string.
-- ---------------------------------------------------------------------------
create table if not exists public.config (
  key   text primary key,
  value text not null
);

-- Seed defaults (engineering plan). on conflict do nothing so re-runs are safe.
insert into public.config (key, value) values
  ('trial_duration_days',     '14'),
  ('trial_recipe_cap',        '14'),
  ('paid_recipe_cap',         '100'),
  ('byok_cutoff_enabled',     'false'),
  ('byok_cutoff_date',        'null'),
  -- Abuse thresholds (engineering plan "Abuse Thresholds" section).
  ('abuse_recipes_per_day',   '20'),
  ('abuse_recipes_per_period','150'),
  ('abuse_chat_per_recipe',   '200'),
  ('abuse_off_topic_rate',    '0.30')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- memories
-- ---------------------------------------------------------------------------
create table if not exists public.memories (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id),
  text       text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists memories_user_id_idx on public.memories (user_id);

-- ---------------------------------------------------------------------------
-- preferences (one row per user)
-- ---------------------------------------------------------------------------
create table if not exists public.preferences (
  user_id             uuid primary key references public.users(id),
  hard_avoids         text[] not null default '{}',
  serving_size        integer,
  equipment           text[] not null default '{}',
  custom_instructions text,
  personality_mode    text check (personality_mode in ('minimal','normal','playful')),
  updated_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- deleted_accounts (tombstone for re-registration check)
-- ---------------------------------------------------------------------------
create table if not exists public.deleted_accounts (
  apple_sub  text primary key,
  deleted_at timestamptz not null default now()
);

-- ===========================================================================
-- Row Level Security
--
-- Enable RLS on every table and create NO permissive policies. With RLS on and
-- no policy, anon/authenticated clients (using the Supabase anon key) are denied
-- all access. The API layer connects with the service_role key, which bypasses
-- RLS entirely — so all reads/writes go through the API, never the client.
--
-- The explicit "deny all" policies below are documentation: they make the intent
-- obvious in the Supabase dashboard and guard against a future accidental
-- "enable anon access" toggle.
-- ===========================================================================
alter table public.users               enable row level security;
alter table public.sessions            enable row level security;
alter table public.subscriptions       enable row level security;
alter table public.usage_events        enable row level security;
alter table public.recipe_cap_counters enable row level security;
alter table public.config              enable row level security;
alter table public.memories            enable row level security;
alter table public.preferences         enable row level security;
alter table public.deleted_accounts    enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array[
    'users','sessions','subscriptions','usage_events','recipe_cap_counters',
    'config','memories','preferences','deleted_accounts'
  ]
  loop
    execute format(
      'drop policy if exists deny_all_%1$s on public.%1$I;', t
    );
    execute format(
      'create policy deny_all_%1$s on public.%1$I for all using (false) with check (false);', t
    );
  end loop;
end $$;
