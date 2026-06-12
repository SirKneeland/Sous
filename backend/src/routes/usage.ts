// /api/v1/usage/* — all stubbed until Project 3 (API Proxy + Instrumentation).

import { Hono } from 'hono';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { notImplemented } from './stubs.js';

export function usageRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();
  app.use('*', authMiddleware);

  app.post('/recipe', notImplemented('usage/recipe', 3));
  app.post('/request', notImplemented('usage/request', 3));
  app.get('/summary', notImplemented('usage/summary', 3));

  return app;
}
