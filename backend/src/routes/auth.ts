// /api/v1/auth/* — Sign in with Apple, sign-out, account deletion.

import { Hono } from 'hono';
import { z } from 'zod';
import { randomUUID } from 'node:crypto';
import type { HonoEnv, AppDeps } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { signSessionToken } from '../lib/tokens.js';
import { hashAppleSub } from '../lib/secrets.js';
import { generateReferralCode } from '../lib/referral.js';
import { computeEntitlement } from '../lib/entitlement.js';
import { entitlementConfigFrom, trialDurationDays, parseConfig, byokCutoffEnabled, byokCutoffDate } from '../lib/config.js';
import { computeByokEligibility } from '../lib/byokEligibility.js';
import type { UserRow, SubscriptionRow } from '../db/types.js';

const appleBody = z.object({
  identityToken: z.string().min(1),
  referralCode: z.string().trim().min(1).optional(),
});

/** Issue and persist a fresh 30-day session token for a user. */
async function issueSession(deps: AppDeps, userId: string): Promise<string> {
  const sessionId = randomUUID();
  const { token, expiresAt } = await signSessionToken(
    { userId, sessionId },
    deps.jwtSecret,
  );
  await deps.repo.insertSession({
    id: sessionId,
    userId,
    token,
    expiresAt: expiresAt.toISOString(),
  });
  return token;
}

/** Build the entitlement object for an auth/config response. */
async function entitlementFor(
  deps: AppDeps,
  user: UserRow,
  subscription: SubscriptionRow | null,
  rawConfig: Record<string, string>,
) {
  return computeEntitlement(
    { is_byok_eligible: user.is_byok_eligible },
    subscription,
    entitlementConfigFrom(rawConfig),
  );
}

/** Read-only user profile surfaced to the iOS Account section. */
function profileFor(user: UserRow) {
  return {
    userId: user.id,
    email: user.email,
    displayName: user.display_name,
    referralCode: user.referral_code,
    isByokEligible: user.is_byok_eligible,
  };
}

export function authRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();

  // POST /auth/apple — exchange an Apple identity token for a Sous session.
  app.post('/apple', async (c) => {
    const deps = c.get('deps');

    const parsed = appleBody.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: 'bad_request', message: 'Expected { identityToken, referralCode? }' }, 400);
    }
    const { identityToken, referralCode } = parsed.data;

    // Verify Apple identity token (or dev-bypass) → canonical Apple sub.
    let identity;
    try {
      identity = await deps.verifyApple(identityToken);
    } catch (err) {
      return c.json({ error: 'invalid_apple_token', message: (err as Error).message }, 401);
    }

    let rawConfig: Record<string, string>;
    try {
      rawConfig = await deps.repo.getConfigAll();
    } catch (err) {
      console.error('[auth/apple] getConfigAll failed:', err);
      throw err;
    }

    // Existing (non-deleted) user → just fetch + issue a new session.
    let existing: UserRow | null;
    try {
      existing = await deps.repo.getUserByAppleSub(identity.sub);
    } catch (err) {
      console.error('[auth/apple] getUserByAppleSub failed:', err);
      throw err;
    }
    if (existing && !existing.is_deleted) {
      const subscription = await deps.repo.getSubscriptionByUserId(existing.id);
      const token = await issueSession(deps, existing.id);
      const entitlement = await entitlementFor(deps, existing, subscription, rawConfig);
      return c.json({
        token,
        userId: existing.id,
        entitlement,
        profile: profileFor(existing),
        config: parseConfig(rawConfig),
      });
    }

    // New account (or a previously-deleted apple_sub re-registering). The tombstone
    // stores a one-way hash of apple_sub, so hash the incoming identity the same way
    // before looking it up.
    const tombstoned = await deps.repo.getDeletedAccount(
      hashAppleSub(identity.sub, deps.env.accountDeletionHashSecret),
    );

    // Resolve referrer if a code was supplied (best-effort; unknown code is ignored).
    let referredByUserId: string | null = null;
    if (referralCode) {
      const referrer = await deps.repo.getUserByReferralCode(referralCode);
      if (referrer && !referrer.is_deleted) referredByUserId = referrer.id;
    }

    const isByokEligible = computeByokEligibility(
      deps.now(),
      byokCutoffEnabled(rawConfig),
      byokCutoffDate(rawConfig),
    );

    const user = await deps.repo.createUser({
      appleSub: identity.sub,
      email: identity.email ?? null,
      referralCode: generateReferralCode(),
      referredByUserId,
      isByokEligible,
    });

    let subscription: SubscriptionRow;
    if (tombstoned) {
      // Re-registration after deletion: no fresh trial. Stored as soft_wall so
      // entitlement computes to soft_wall. (See schema.sql flagged deviation.)
      subscription = await deps.repo.createSubscription({
        userId: user.id,
        status: 'soft_wall',
        trialStartedAt: null,
        trialEndsAt: null,
      });
    } else {
      const now = new Date();
      const trialEnds = new Date(
        now.getTime() + trialDurationDays(rawConfig) * 24 * 60 * 60 * 1000,
      );
      subscription = await deps.repo.createSubscription({
        userId: user.id,
        status: 'trialing',
        trialStartedAt: now.toISOString(),
        trialEndsAt: trialEnds.toISOString(),
      });
    }

    const token = await issueSession(deps, user.id);
    const entitlement = await entitlementFor(deps, user, subscription, rawConfig);
    return c.json({
      token,
      userId: user.id,
      entitlement,
      profile: profileFor(user),
      config: parseConfig(rawConfig),
    });
  });

  // POST /auth/signout — revoke the current session token.
  app.post('/signout', authMiddleware, async (c) => {
    const deps = c.get('deps');
    const header = c.req.header('Authorization') ?? '';
    const token = header.replace(/^Bearer\s+/i, '').trim();
    await deps.repo.revokeSession(token);
    return c.json({ ok: true });
  });

  // DELETE /auth/account — purge PII, write a hashed tombstone, revoke all sessions.
  // The user row is kept (scrubbed) for FK integrity and abuse/billing retention;
  // preferences + memories are hard-deleted; the subscription is left untouched. The
  // whole purge runs atomically in the repo (see purge_deleted_account).
  app.delete('/account', authMiddleware, async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const user = await deps.repo.getUserById(userId);
    if (!user) {
      return c.json({ error: 'not_found', message: 'User not found' }, 404);
    }
    // Short-circuit ONLY on a null apple_sub, which is the post-purge signal: the
    // sole writer of that null is the atomic purge_deleted_account function, which
    // commits all-or-nothing, so apple_sub === null ⟺ the purge ran to completion.
    // We deliberately do NOT short-circuit on is_deleted alone — a row that is
    // is_deleted=true but still has a non-null apple_sub means a prior purge did NOT
    // complete (e.g. a legacy soft-delete-only row, or a half-applied state), so we
    // fall through and actually purge it rather than reporting "already handled".
    if (user.apple_sub === null) {
      return c.json({ ok: true });
    }
    const now = new Date().toISOString();
    // Hash apple_sub BEFORE the purge scrubs it to null — we need the original value.
    const appleSubHash = hashAppleSub(user.apple_sub, deps.env.accountDeletionHashSecret);
    await deps.repo.purgeAccount(userId, appleSubHash, now);
    return c.json({ ok: true });
  });

  return app;
}
