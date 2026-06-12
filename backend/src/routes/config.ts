// /api/v1/config — remote config + current entitlement. Auth required.

import { Hono } from 'hono';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { computeEntitlement } from '../lib/entitlement.js';
import { entitlementConfigFrom, parseConfig } from '../lib/config.js';

export function configRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();

  app.use('*', authMiddleware);

  // GET /config — flat key/value config plus this user's entitlement status.
  app.get('/', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');

    const rawConfig = await deps.repo.getConfigAll();
    const user = await deps.repo.getUserById(userId);
    if (!user) {
      return c.json({ error: 'not_found', message: 'User not found' }, 404);
    }
    const subscription = await deps.repo.getSubscriptionByUserId(userId);

    const entitlement = computeEntitlement(
      { is_byok_eligible: user.is_byok_eligible },
      subscription,
      entitlementConfigFrom(rawConfig),
    );

    return c.json({
      config: parseConfig(rawConfig),
      entitlement,
    });
  });

  return app;
}
