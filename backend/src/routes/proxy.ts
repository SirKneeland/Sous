// /api/v1/proxy/* — OpenAI proxy. Stubbed until Project 3.

import { Hono } from 'hono';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { notImplemented } from './stubs.js';

export function proxyRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();
  app.use('*', authMiddleware);

  app.post('/chat', notImplemented('proxy/chat', 3));
  app.post('/tts', notImplemented('proxy/tts', 3));

  return app;
}
