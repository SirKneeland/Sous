// /api/v1/subscription/* — status (Project 1), validate + notify (Project 4).
//
// validate: the iOS client posts a StoreKit 2 signed transaction after a purchase
//   or restore. We verify it cryptographically against Apple's PKI (see
//   lib/appstore.ts), then write the subscription row to `active` and return the
//   recomputed entitlement.
// notify:  Apple's App Store Server Notifications v2 webhook. We verify the signed
//   payload, map the notificationType to a subscription status, and update the row.
//   Replay/spoofing is prevented by the Apple JWS signature; handlers are
//   idempotent so a legitimate Apple retry is harmless. Always returns 200 for
//   handled events so Apple does not retry needlessly.

import { Hono } from 'hono';
import { z } from 'zod';
import type { HonoEnv } from '../types.js';
import type { SubscriptionStatus } from '../db/types.js';
import { authMiddleware } from '../middleware/auth.js';
import { computeEntitlement } from '../lib/entitlement.js';
import { entitlementConfigFrom } from '../lib/config.js';
import { AppStoreVerifyError } from '../lib/appstore.js';
import { timingSafeEqualStr } from '../lib/secrets.js';

const validateBodySchema = z.object({
  receiptData: z.string().min(1),
});

const notifyBodySchema = z.object({
  signedPayload: z.string().min(1),
});

export function subscriptionRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();

  // GET /subscription/status — entitlement + the raw subscription row.
  // (Auth-scoped: only this route needs the user session, so auth runs here
  // rather than app-wide — the notify webhook below is called by Apple, not a
  // signed-in user, and must stay unauthenticated.)
  app.get('/status', authMiddleware, async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');

    const user = await deps.repo.getUserById(userId);
    if (!user) {
      return c.json({ error: 'not_found', message: 'User not found' }, 404);
    }
    const subscription = await deps.repo.getSubscriptionByUserId(userId);
    const rawConfig = await deps.repo.getConfigAll();

    const entitlement = computeEntitlement(
      { is_byok_eligible: user.is_byok_eligible },
      subscription,
      entitlementConfigFrom(rawConfig),
      deps.now(),
    );

    const profile = {
      userId: user.id,
      email: user.email,
      displayName: user.display_name,
      referralCode: user.referral_code,
      isByokEligible: user.is_byok_eligible,
    };

    return c.json({ entitlement, subscription, profile });
  });

  // POST /subscription/validate — verify a StoreKit purchase/restore, activate.
  app.post('/validate', authMiddleware, async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');

    const parsed = validateBodySchema.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: 'bad_request', message: 'Missing receiptData' }, 400);
    }

    // Verify the signed transaction. Sandbox and production transactions verify by
    // the same cryptographic path; the environment field distinguishes them.
    let txn;
    try {
      txn = await deps.appstore.verifyTransaction(parsed.data.receiptData);
    } catch (err) {
      if (err instanceof AppStoreVerifyError || err instanceof Error) {
        return c.json({ error: 'invalid_receipt', message: 'Receipt could not be verified' }, 400);
      }
      throw err;
    }

    // A revoked/refunded transaction must never grant access.
    if (txn.revocationDate) {
      return c.json({ error: 'invalid_receipt', message: 'Transaction has been revoked' }, 400);
    }

    // Bind a transaction to a single Sous account. The JWS proves the transaction
    // is genuine, NOT that it belongs to this caller — without this check a shared
    // signed transaction could upgrade many accounts off one purchase. If this
    // original transaction id is already attached to a different user, refuse.
    const existingOwner = await deps.repo.getSubscriptionByOriginalTransactionId(
      txn.originalTransactionId,
    );
    if (existingOwner && existingOwner.user_id !== userId) {
      return c.json(
        {
          error: 'transaction_already_claimed',
          message: 'This subscription is already linked to another account.',
        },
        409,
      );
    }

    const subscription = await deps.repo.updateSubscriptionFromApple(userId, {
      status: 'active',
      appleOriginalTransactionId: txn.originalTransactionId,
      currentPeriodStart: txn.purchaseDate,
      currentPeriodEnd: txn.expiresDate,
      appleLatestReceipt: parsed.data.receiptData,
    });

    const user = await deps.repo.getUserById(userId);
    const rawConfig = await deps.repo.getConfigAll();
    const entitlement = computeEntitlement(
      { is_byok_eligible: user?.is_byok_eligible ?? false },
      subscription,
      entitlementConfigFrom(rawConfig),
      deps.now(),
    );

    if (deps.env.nodeEnv !== 'production') {
      console.log(
        `[subscription/validate] user=${userId} env=${txn.environment} status=${subscription.status} entitlement=${entitlement.status}`,
      );
    }

    return c.json({ entitlement, subscription });
  });

  // POST /subscription/notify — App Store Server Notifications v2 webhook.
  // Unauthenticated by design (Apple calls it). Trust comes from the Apple JWS
  // signature; an optional shared secret adds a second gate.
  app.post('/notify', async (c) => {
    const deps = c.get('deps');

    // Optional shared-secret gate (?secret= or X-Sous-Notification-Secret).
    const expectedSecret = deps.env.appStoreNotificationSecret;
    if (expectedSecret) {
      const provided =
        c.req.query('secret') ?? c.req.header('X-Sous-Notification-Secret') ?? '';
      if (!timingSafeEqualStr(provided, expectedSecret)) {
        return c.json({ error: 'unauthorized', message: 'Bad notification secret' }, 401);
      }
    }

    const parsed = notifyBodySchema.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: 'bad_request', message: 'Missing signedPayload' }, 400);
    }

    let notification;
    try {
      notification = await deps.appstore.verifyNotification(parsed.data.signedPayload);
    } catch {
      // A payload whose signature does not verify is rejected (not retried as a
      // valid event). Apple's real notifications always verify.
      return c.json({ error: 'invalid_signature', message: 'Notification could not be verified' }, 400);
    }

    const originalTransactionId = notification.transaction?.originalTransactionId;
    if (!originalTransactionId) {
      // Nothing to map (e.g. a TEST notification). Acknowledge so Apple stops.
      if (deps.env.nodeEnv !== 'production') {
        console.log(`[subscription/notify] type=${notification.notificationType} (no transaction) — ack`);
      }
      return c.json({ ok: true }, 200);
    }

    const subscription =
      await deps.repo.getSubscriptionByOriginalTransactionId(originalTransactionId);
    if (!subscription) {
      // We do not recognise this subscription (never validated on our side).
      // Ack to avoid infinite Apple retries; nothing to update.
      if (deps.env.nodeEnv !== 'production') {
        console.log(
          `[subscription/notify] type=${notification.notificationType} unknown originalTransactionId=${originalTransactionId} — ack`,
        );
      }
      return c.json({ ok: true }, 200);
    }

    const mapped = mapNotificationToStatus(notification.notificationType);
    if (!mapped) {
      // Unhandled type — log and ack (do NOT error; Apple retries on non-200).
      if (deps.env.nodeEnv !== 'production') {
        console.log(`[subscription/notify] unhandled type=${notification.notificationType} — ack`);
      }
      return c.json({ ok: true }, 200);
    }

    await deps.repo.updateSubscriptionLifecycle(subscription.id, {
      status: mapped,
      // Carry Apple's expiry through so grace (current_period_end + 7 days) and
      // the active period are anchored to Apple's clock, not ours.
      currentPeriodEnd: notification.transaction?.expiresDate ?? undefined,
    });

    if (deps.env.nodeEnv !== 'production') {
      console.log(
        `[subscription/notify] type=${notification.notificationType} sub=${subscription.id} → ${mapped}`,
      );
    }

    return c.json({ ok: true }, 200);
  });

  return app;
}

/**
 * Map an App Store Server Notification type to the subscription status we store.
 * Returns null for types we intentionally ignore (logged + 200'd by the caller).
 */
function mapNotificationToStatus(type: string): SubscriptionStatus | null {
  switch (type) {
    case 'SUBSCRIBED':
      return 'active';
    case 'DID_RENEW':
      return 'active';
    case 'EXPIRED':
      return 'lapsed';
    case 'DID_FAIL_TO_RENEW':
      // Billing retry / grace period begins. entitlement.ts surfaces `grace` for
      // 7 days from current_period_end, then `soft_wall`.
      return 'lapsed';
    case 'REFUND':
      return 'soft_wall';
    case 'REVOKE':
      return 'soft_wall';
    default:
      return null;
  }
}
