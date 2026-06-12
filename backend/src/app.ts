// createApp — builds the Hono application from injected dependencies.
//
// index.ts wires real dependencies (Supabase, env). Tests wire a fake repo and a
// fake Apple verifier, then drive the app with app.request(...). No network, no DB.

import { Hono } from 'hono';
import { logger } from 'hono/logger';
import type { AppDeps, HonoEnv } from './types.js';
import { authRoutes } from './routes/auth.js';
import { configRoutes } from './routes/config.js';
import { subscriptionRoutes } from './routes/subscription.js';
import { usageRoutes } from './routes/usage.js';
import { proxyRoutes } from './routes/proxy.js';
import { syncRoutes } from './routes/sync.js';
import { referralRoutes } from './routes/referral.js';

export function createApp(deps: AppDeps): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();

  app.use('*', logger());

  // Make deps available to every handler and middleware.
  app.use('*', async (c, next) => {
    c.set('deps', deps);
    await next();
  });

  // Health check — no auth. Railway pings this to confirm the service is up.
  app.get('/health', (c) => c.json({ status: 'ok' }));

  // Versioned API surface.
  const api = new Hono<HonoEnv>();
  api.route('/auth', authRoutes());
  api.route('/config', configRoutes());
  api.route('/subscription', subscriptionRoutes());
  api.route('/usage', usageRoutes());
  api.route('/proxy', proxyRoutes());
  api.route('/sync', syncRoutes());
  api.route('/referral', referralRoutes());

  app.route('/api/v1', api);

  app.notFound((c) => c.json({ error: 'not_found', message: 'Unknown route' }, 404));
  app.onError((err, c) => {
    console.error('Unhandled error:', err);
    return c.json({ error: 'internal_error', message: 'Something went wrong' }, 500);
  });

  return app;
}
