// /api/v1/subscription/* — status implemented; validate/notify stubbed (Project 4).

import { Hono } from 'hono';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { computeEntitlement } from '../lib/entitlement.js';
import { entitlementConfigFrom } from '../lib/config.js';
import { notImplemented } from './stubs.js';

export function subscriptionRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();

  app.use('*', authMiddleware);

  // GET /subscription/status — entitlement + the raw subscription row.
  app.get('/status', async (c) => {
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
    );

    return c.json({ entitlement, subscription });
  });

  // Stubs — implemented in Project 4 (Billing + Paywall).
  app.post('/validate', notImplemented('subscription/validate', 4));
  app.post('/notify', notImplemented('subscription/notify', 4));

  return app;
}
