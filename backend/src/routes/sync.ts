// /api/v1/sync/* — preferences / memories / recipes sync. Stubbed until Project 2/3.

import { Hono } from 'hono';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { notImplemented } from './stubs.js';

export function syncRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();
  app.use('*', authMiddleware);

  app.get('/preferences', notImplemented('sync/preferences', 2));
  app.put('/preferences', notImplemented('sync/preferences', 2));
  app.get('/memories', notImplemented('sync/memories', 2));
  app.put('/memories', notImplemented('sync/memories', 2));
  app.get('/recipes', notImplemented('sync/recipes', 3));
  app.put('/recipes/:id', notImplemented('sync/recipes/:id', 3));

  return app;
}
