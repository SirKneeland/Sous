# Sous Backend — Project 1: Backend Foundation

Accounts, entitlement, usage metering (stubbed), and OpenAI proxy (stubbed) for
the Sous iOS app. Node.js + Hono + Supabase, deployed on Railway.

**Authoritative spec:** `../docs/BackendEngineeringPlan.md`

---

## What's implemented in Project 1

- **Full Supabase schema** (`db/schema.sql`) — all 9 tables, seed config, RLS.
- **`POST /api/v1/auth/apple`** — Sign in with Apple → Sous session token.
- **`POST /api/v1/auth/signout`** — revoke current session.
- **`DELETE /api/v1/auth/account`** — soft-delete + tombstone + revoke sessions.
- **`GET /api/v1/config`** — config map + entitlement.
- **`GET /api/v1/subscription/status`** — entitlement + subscription row.
- **`GET /health`** — health check (no auth) for Railway.
- All other endpoints return **501 Not Implemented** (filled in Projects 2–4).

---

## Local development

```
cd backend
npm install
cp .env.example .env      # then fill in the values (see below)
npm run dev               # starts on http://localhost:3000
npm test                  # runs the test suite (no DB needed — uses fakes)
npm run typecheck         # TypeScript type check
```

`.env` is gitignored. Never commit real keys.

---

## Operator setup — Supabase

1. Go to **https://supabase.com** and create an account (free tier is fine).
2. Click **New project**. Name it **`sous-production`**. Pick a region close to
   you and set a strong database password (save it in your password manager).
3. Wait for the project to finish provisioning (~2 minutes).
4. In the left sidebar, open **SQL Editor** → **New query**.
5. Open the file `backend/db/schema.sql` in this repo, copy its **entire**
   contents, paste into the SQL editor, and click **Run**. You should see
   "Success. No rows returned." This creates all tables, seeds config, and
   enables Row Level Security.
6. Get your keys: left sidebar → **Project Settings** (gear icon) → **API**.
   Copy two values:
   - **Project URL** → this is `SUPABASE_URL`
   - **`service_role` secret** (under "Project API keys") → this is
     `SUPABASE_SERVICE_ROLE_KEY`. **Keep this secret** — it bypasses all
     security rules. Never put it in the iOS app or anywhere public.
7. Paste both into `backend/.env`.

To confirm the tables exist: left sidebar → **Table Editor**. You should see
`users`, `sessions`, `subscriptions`, `usage_events`, `recipe_cap_counters`,
`config`, `memories`, `preferences`, `deleted_accounts`. Open `config` and
confirm the seed rows (e.g. `trial_duration_days = 14`).

`schema.sql` is idempotent — re-run the whole file any time the schema changes
(it adds the account-deletion purge function and the PII backfills without
disturbing existing data).

**One-time backfill (only if accounts were already deleted under the old
behavior):** the deleted-account tombstones now store a hashed Apple identifier
instead of the raw one. That rewrite can't be done in SQL (it needs the app
secret), so after deploying, run it once with `ACCOUNT_DELETION_HASH_SECRET` set:

```
cd backend
node --env-file=.env --import tsx scripts/backfill-deleted-account-hashes.ts
```

It's safe to run more than once (already-hashed rows are skipped). On a brand-new
project with no deletions yet, you can skip it.

---

## Operator setup — environment variables

`backend/.env` needs these four values:

```
SUPABASE_URL=                  # from Supabase → Project Settings → API → Project URL
SUPABASE_SERVICE_ROLE_KEY=     # from Supabase → Project Settings → API → service_role secret
JWT_SECRET=                    # a long random string — generate one (see below)
ACCOUNT_DELETION_HASH_SECRET=  # a long random string — generate one (see below)
PORT=3000
NODE_ENV=development
```

Generate `JWT_SECRET` and `ACCOUNT_DELETION_HASH_SECRET` by running this in your
terminal twice and pasting each output:

```
openssl rand -base64 48
```

> **`ACCOUNT_DELETION_HASH_SECRET` is required** — the server will not boot without
> it. Account deletion stores a one-way hash (not the raw Apple identifier) of every
> deleted account so a deleted user can't restart their free trial; this secret is
> the hash key. **Set it once and never change it** — changing it after any account
> has been deleted would let those users start a fresh trial again.

For **Postman testing without a real iPhone**, also add:

```
BYPASS_APPLE_VERIFY=true
```

This skips Apple token verification in development. It is **automatically ignored
when `NODE_ENV=production`**, so it can never weaken the live server.

---

## Operator setup — Railway deployment

1. Go to **https://railway.app** and sign in with your GitHub account.
2. Click **New Project** → **Deploy from GitHub repo** → select the **Sous** repo.
   (You may need to grant Railway access to the repo first.)
3. After it creates the service, open the service → **Settings**:
   - Under **Source / Root Directory**, set the root directory to **`backend`**.
   - Railway auto-detects Node and uses `npm start` (already configured in
     `railway.json` and `package.json`).
4. Open the service → **Variables** and add each of these (same values as your
   `.env`, but set `NODE_ENV=production` and **do not** set `BYPASS_APPLE_VERIFY`,
   or set it to `false`):
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `JWT_SECRET`
   - `ACCOUNT_DELETION_HASH_SECRET` (required; set once, never change — see note above)
   - `NODE_ENV=production`
   - (Railway sets `PORT` automatically — you do not need to add it.)
5. Railway will build and deploy. When it's live, open the service →
   **Settings** → **Networking** → **Generate Domain** to get a public URL.
6. Confirm it's running: visit `https://<your-railway-domain>/health` in a
   browser. You should see `{"status":"ok"}`.

Every push to the repo's default branch will redeploy automatically.

---

## Operator setup — Postman verification

1. Download and install Postman from **https://www.postman.com/downloads/**.
2. Create a new **Collection** called **"Sous Backend"**.
3. **Health check:**
   - Add a request: **GET** `https://<your-railway-domain>/health`
     (or `http://localhost:3000/health` for local).
   - Click **Send**. Expect **200 OK** and body `{"status":"ok"}`.
4. **Create an account (dev bypass):** this works because `BYPASS_APPLE_VERIFY=true`
   is set locally. (On production with `NODE_ENV=production`, a *real* Apple
   identity token from the iPhone app is required — that's Project 2.)
   - Add a request: **POST** `http://localhost:3000/api/v1/auth/apple`
   - Body → **raw** → **JSON**:
     ```json
     { "identityToken": "test-user-1" }
     ```
   - Click **Send**. Expect **200 OK** with a body containing `token`, `userId`,
     `entitlement` (status `"trialing"`), and `config`.
   - In dev bypass, the `identityToken` string is treated as the Apple user id,
     so sending the same value again returns the **same `userId`** (returning
     user), and a different value creates a new account.
5. **Use the token:** copy the `token` from the previous response.
   - Add a request: **GET** `http://localhost:3000/api/v1/config`
   - Under **Authorization**, choose **Bearer Token** and paste the token.
   - Click **Send**. Expect **200 OK** with `config` (e.g.
     `trial_duration_days: 14`) and `entitlement`.
   - Try the same request **without** the token → expect **401 Unauthorized**.

---

## Architecture notes

- All DB access goes through the API using the **service-role** key. RLS is
  enabled on every table with deny-all policies, so the Supabase anon key (used
  by clients) can read/write nothing directly. The iOS app never talks to
  Supabase — only to this API.
- Session tokens are signed JWTs (30-day expiry) **and** stored in `sessions`,
  so sign-out and account deletion revoke access immediately.
- Entitlement is computed server-side (`lib/entitlement.ts`) and is the single
  source of truth. The five states: `byok`, `subscriber`, `trialing`, `grace`,
  `soft_wall`.
