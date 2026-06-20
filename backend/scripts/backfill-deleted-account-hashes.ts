// One-time backfill: re-hash plaintext apple_sub tombstones.
//
// Before the account-deletion privacy hardening, deleted_accounts stored the raw
// apple_sub as its primary key. This script rewrites every row that still holds a
// raw value into a one-way HMAC (the same hash the live code now writes), so the
// re-registration trial-denial check keeps working after the change.
//
// WHY A SCRIPT (not pure SQL, not a startup migration): an HMAC needs the
// application secret (ACCOUNT_DELETION_HASH_SECRET), which SQL cannot compute. We
// keep it out of server boot so this privacy-critical, run-once operation is an
// explicit operator step rather than something that fires on every deploy.
//
// HOW TO RUN (once, after deploying the schema change):
//   cd backend
//   node --env-file=.env --import tsx scripts/backfill-deleted-account-hashes.ts
//
// It is safe to run more than once: rows that already look hashed (64-char lower
// hex) are skipped, so already-migrated tombstones are left alone.

import { createSupabaseClient } from '../src/db/client.js';
import { hashAppleSub } from '../src/lib/secrets.js';

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name} (see .env.example)`);
  return v;
}

/** A value already migrated is the 64-char lowercase-hex HMAC digest. */
function looksHashed(value: string): boolean {
  return /^[0-9a-f]{64}$/.test(value);
}

async function main() {
  const secret = requireEnv('ACCOUNT_DELETION_HASH_SECRET');
  const db = createSupabaseClient(
    requireEnv('SUPABASE_URL'),
    requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
  );

  const { data, error } = await db.from('deleted_accounts').select('apple_sub, deleted_at');
  if (error) throw error;
  const rows = (data as { apple_sub: string; deleted_at: string }[]) ?? [];

  let migrated = 0;
  let skipped = 0;
  for (const row of rows) {
    if (looksHashed(row.apple_sub)) {
      skipped += 1;
      continue;
    }
    const hashed = hashAppleSub(row.apple_sub, secret);
    // Insert the hashed row, then delete the plaintext one. (apple_sub is the PK, so
    // we cannot UPDATE the key in place without a transient duplicate; insert+delete
    // is the safe two-step. Idempotent on re-run because the new row looks hashed.)
    const { error: insErr } = await db
      .from('deleted_accounts')
      .upsert({ apple_sub: hashed, deleted_at: row.deleted_at });
    if (insErr) throw insErr;
    const { error: delErr } = await db
      .from('deleted_accounts')
      .delete()
      .eq('apple_sub', row.apple_sub);
    if (delErr) throw delErr;
    migrated += 1;
  }

  console.log(
    `deleted_accounts backfill complete: ${migrated} migrated, ${skipped} already hashed, ${rows.length} total.`,
  );
}

main().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
