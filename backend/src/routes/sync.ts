// /api/v1/sync/* — preferences / memories / profile sync.
//
// Project 2 implements preferences, memories, and the editable display-name
// (profile) endpoints. Recipe-session sync stays stubbed until Project 3.

import { Hono } from 'hono';
import { z } from 'zod';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { notImplemented } from './stubs.js';
import type { PreferencesRow, MemoryRow } from '../db/types.js';

// The personality modes the iOS app can send. The DB CHECK constraint is widened
// to match (see schema.sql); unknown values are coerced to null defensively so a
// future client value can never hard-fail the whole preferences sync.
const PERSONALITY_MODES = ['minimal', 'normal', 'playful', 'unhinged'] as const;

const preferencesBody = z.object({
  hardAvoids: z.array(z.string()).default([]),
  servingSize: z.number().int().nullable().default(null),
  equipment: z.array(z.string()).default([]),
  customInstructions: z.string().nullable().default(null),
  personalityMode: z.string().nullable().default(null),
});

const memoriesBody = z.object({
  memories: z
    .array(
      z.object({
        id: z.string().optional(),
        text: z.string().min(1),
        createdAt: z.string().optional(),
      }),
    )
    .default([]),
});

const profileBody = z.object({
  displayName: z.string().trim().max(100).nullable().default(null),
});

/** Shape preferences for the client (camelCase, server is source of truth). */
function preferencesDTO(row: PreferencesRow | null) {
  return {
    hardAvoids: row?.hard_avoids ?? [],
    servingSize: row?.serving_size ?? null,
    equipment: row?.equipment ?? [],
    customInstructions: row?.custom_instructions ?? null,
    personalityMode: row?.personality_mode ?? null,
  };
}

/** Shape one memory for the client. */
function memoryDTO(row: MemoryRow) {
  return { id: row.id, text: row.text, createdAt: row.created_at };
}

export function syncRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();
  app.use('*', authMiddleware);

  // GET /sync/preferences — fetch this user's saved preferences (may be empty).
  app.get('/preferences', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const row = await deps.repo.getPreferences(userId);
    return c.json({ preferences: preferencesDTO(row) });
  });

  // PUT /sync/preferences — replace this user's preferences.
  app.put('/preferences', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const parsed = preferencesBody.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: 'bad_request', message: 'Invalid preferences body' }, 400);
    }
    const p = parsed.data;
    const personalityMode =
      p.personalityMode && (PERSONALITY_MODES as readonly string[]).includes(p.personalityMode)
        ? p.personalityMode
        : null;
    const row = await deps.repo.upsertPreferences(userId, {
      hardAvoids: p.hardAvoids,
      servingSize: p.servingSize,
      equipment: p.equipment,
      customInstructions: p.customInstructions,
      personalityMode,
    });
    return c.json({ preferences: preferencesDTO(row) });
  });

  // GET /sync/memories — fetch all memories, oldest first.
  app.get('/memories', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const rows = await deps.repo.getMemories(userId);
    return c.json({ memories: rows.map(memoryDTO) });
  });

  // PUT /sync/memories — replace the full memory list.
  app.put('/memories', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const parsed = memoriesBody.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: 'bad_request', message: 'Invalid memories body' }, 400);
    }
    const rows = await deps.repo.replaceMemories(userId, parsed.data.memories);
    return c.json({ memories: rows.map(memoryDTO) });
  });

  // PUT /sync/profile — update the editable display name.
  app.put('/profile', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const parsed = profileBody.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: 'bad_request', message: 'Invalid profile body' }, 400);
    }
    const displayName = parsed.data.displayName?.length ? parsed.data.displayName : null;
    await deps.repo.updateDisplayName(userId, displayName);
    return c.json({ displayName });
  });

  // Recipe-session sync — implemented in Project 3.
  app.get('/recipes', notImplemented('sync/recipes', 3));
  app.put('/recipes/:id', notImplemented('sync/recipes/:id', 3));

  return app;
}
