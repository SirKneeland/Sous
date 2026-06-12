// /api/v1/referral/* — referral code read + apply. Stubbed until Project 4.
// (Referral codes are still generated and applied at signup in /auth/apple; these
// endpoints are the standalone read/apply surface, finished alongside billing.)

import { Hono } from 'hono';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { notImplemented } from './stubs.js';

export function referralRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();
  app.use('*', authMiddleware);

  app.get('/code', notImplemented('referral/code', 4));
  app.post('/apply', notImplemented('referral/apply', 4));

  return app;
}
