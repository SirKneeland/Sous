// /api/v1/auth/* — Sign in with Apple, sign-out, account deletion.

import { Hono } from 'hono';
import { z } from 'zod';
import { randomUUID } from 'node:crypto';
import type { HonoEnv, AppDeps } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { signSessionToken } from '../lib/tokens.js';
import { generateReferralCode } from '../lib/referral.js';
import { computeEntitlement } from '../lib/entitlement.js';
import { entitlementConfigFrom, trialDurationDays, parseConfig } from '../lib/config.js';
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
        config: parseConfig(rawConfig),
      });
    }

    // New account (or a previously-deleted apple_sub re-registering).
    const tombstoned = await deps.repo.getDeletedAccount(identity.sub);

    // Resolve referrer if a code was supplied (best-effort; unknown code is ignored).
    let referredByUserId: string | null = null;
    if (referralCode) {
      const referrer = await deps.repo.getUserByReferralCode(referralCode);
      if (referrer && !referrer.is_deleted) referredByUserId = referrer.id;
    }

    const user = await deps.repo.createUser({
      appleSub: identity.sub,
      email: identity.email ?? null,
      referralCode: generateReferralCode(),
      referredByUserId,
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

  // DELETE /auth/account — soft-delete + tombstone + revoke all sessions.
  app.delete('/account', authMiddleware, async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const user = await deps.repo.getUserById(userId);
    if (!user) {
      return c.json({ error: 'not_found', message: 'User not found' }, 404);
    }
    const now = new Date().toISOString();
    await deps.repo.softDeleteUser(userId, now);
    await deps.repo.insertDeletedAccount(user.apple_sub, now);
    await deps.repo.revokeAllSessionsForUser(userId);
    return c.json({ ok: true });
  });

  return app;
}
