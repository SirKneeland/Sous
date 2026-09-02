# Database Backups — Operator Runbook

## Why this exists

In September 2026 the Supabase project behind the Sous backend became
unreachable (DNS NXDOMAIN) and the database was lost. There was no backup.
No users were affected because there were none yet. That is the only reason
it was survivable.

The Supabase **free plan provides no automatic backups at all**, and pauses
projects after ~7 days of inactivity. Supabase's own guidance for free-plan
users is to take your own off-site dumps.

## What runs

`.github/workflows/db-backup.yml` — daily at 09:17 UTC, plus a manual
"Run workflow" button in the Actions tab.

Each run:
1. Dumps roles, schema, and data via the Supabase CLI.
2. **Verifies the dump is non-empty and contains tables.** A silent empty
   backup is worse than none, because it looks healthy.
3. Encrypts the bundle with AES256 (GPG symmetric).
4. Commits it to the private `sous-db-backups` repo under `dumps/YYYY-MM-DD/`.
5. Prunes to the most recent 30 days.

**The daily dump doubles as the keep-warm ping.** It is a real database
connection every day, which is what prevents free-tier pausing. If you
disable this workflow, you lose backups *and* re-expose yourself to pausing.

## Why the backups are encrypted

The dump contains `apple_sub`, `email`, `phone_number`, and **live session
tokens** from the `sessions` table. Anyone who can read an unencrypted dump
can impersonate users. A private repo is not sufficient protection on its
own. **Never remove the encryption step.**

Store `BACKUP_PASSPHRASE` in your password manager. If you lose it, every
backup is permanently unreadable — the encryption has no recovery path.

## Required secrets

Set on the **Sous** repo (Settings → Secrets and variables → Actions):

| Secret | What it is |
|---|---|
| `SUPABASE_DB_URL` | Postgres connection string. Supabase dashboard → Project Settings → Database → Connection string (URI). Includes the DB password. |
| `BACKUP_PASSPHRASE` | Long random string you generate: `openssl rand -base64 32`. Save in your password manager. |
| `BACKUP_REPO_TOKEN` | GitHub PAT with `Contents: read/write` on `sous-db-backups` only. |

## Restore procedure

**Test this before you have real users. An untested backup is not a backup.**

1. Get the archive from `sous-db-backups/dumps/<date>/`.
2. Decrypt and unpack:

   ```bash
   gpg --decrypt sous-db-<date>.tar.gz.gpg | tar xzf - -C restore/
   ```

3. Create a new Supabase project (or resume the existing one).
4. Restore in this order — order matters, data depends on schema:

   ```bash
   psql "$NEW_DB_URL" -f restore/roles.sql
   psql "$NEW_DB_URL" -f restore/schema.sql
   psql "$NEW_DB_URL" -f restore/data.sql
   ```

5. Update `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in Railway.
   Leave `ACCOUNT_DELETION_HASH_SECRET` alone — changing it orphans every
   account-deletion tombstone.
6. Verify: `curl https://sous-production-9a1d.up.railway.app/health` returns
   `{"status":"ok"}`, and the admin dashboard returns 200 rather than 500
   (it reads five tables, so it is the best single end-to-end check).

## Known limitations

- **`BACKUP_REPO_TOKEN` expires 2 January 2027.** When it does, backups stop
  and the only signal is a failed-workflow email. A calendar reminder is set
  for 18 December 2026. Renewing means generating a new fine-grained token
  (repo access: `sous-db-backups` only; Contents: read/write) and updating the
  secret. Consider a longer expiry, or no expiry, on renewal.
- **GitHub disables scheduled workflows after 60 days of no activity in the
  Sous repo.** If you stop committing for two months, backups stop silently.
  GitHub emails a warning first. If Sous is going dormant, either commit
  something occasionally or move to Supabase Pro.
- Only protects against data loss, not against Railway or GitHub outages.
- Retention is 30 days. Older backups are deleted permanently.
- On Supabase **Pro**, daily managed backups exist too — but they live in the
  same account that can fail or be locked, so keep these independent ones.
