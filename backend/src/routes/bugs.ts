// /api/v1/bugs — in-app bug submission.
//
// The iOS 5-tap diagnostic used to go straight to an iOS share sheet. It now also
// posts here, so a report lands in a triage backlog instead of an AirDropped file.
// The operator reads and triages via /api/v1/admin/bugs* (admin key, not a session
// token) — see backend/scripts/bugs.sh and docs/BugTriage.md.
//
// Reports are never deleted. Triage moves `status`; resolved reports stay as
// source material for regression tests.

import { Hono } from 'hono';
import { z } from 'zod';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';

/**
 * Largest diagnostic we will store. The iOS exporter already truncates each
 * captured blob at 20k characters, so a report well past this is a bug in the
 * exporter rather than an unusually chatty session.
 */
export const MAX_DIAGNOSTIC_CHARS = 512_000;

/** Ceiling on the free-text fields the user types. */
export const MAX_DESCRIPTION_CHARS = 4_000;

/**
 * Submissions allowed per user per rolling hour. Generous for a human tapping
 * five times, low enough that a stuck retry loop cannot fill the table.
 */
export const BUG_RATE_LIMIT_PER_HOUR = 20;

const submitSchema = z.object({
  /** Client-generated, stable across retries of the same report. */
  clientReportId: z.string().uuid(),
  description: z.string().trim().min(1).max(MAX_DESCRIPTION_CHARS),
  expectedBehavior: z.string().trim().max(MAX_DESCRIPTION_CHARS).optional(),
  diagnostic: z.string().min(1).max(MAX_DIAGNOSTIC_CHARS),
  appVersion: z.string().max(64).optional(),
  buildNumber: z.string().max(64).optional(),
  iosVersion: z.string().max(64).optional(),
  deviceModel: z.string().max(128).optional(),
  appState: z.string().max(128).optional(),
});

export function bugRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();
  app.use('*', authMiddleware);

  // POST /bugs — submit one report.
  app.post('/', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');

    const raw = (await c.req.json().catch(() => null)) as Record<string, unknown> | null;
    if (raw == null) {
      return c.json({ error: 'bad_request', message: 'Expected a JSON body' }, 400);
    }

    // Size is checked before shape so an oversized diagnostic gets a clear 413
    // rather than a generic schema error the client cannot act on.
    if (typeof raw.diagnostic === 'string' && raw.diagnostic.length > MAX_DIAGNOSTIC_CHARS) {
      return c.json(
        {
          error: 'payload_too_large',
          message: `Diagnostic exceeds ${MAX_DIAGNOSTIC_CHARS} characters`,
        },
        413,
      );
    }

    const parsed = submitSchema.safeParse(raw);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      const where = issue?.path.join('.') ?? 'body';
      return c.json(
        { error: 'bad_request', message: `${where}: ${issue?.message ?? 'invalid'}` },
        400,
      );
    }
    const input = parsed.data;

    // Idempotent retry: the same client id returns the original report rather
    // than filing a second copy. A flaky network must not duplicate the backlog.
    const existing = await deps.repo.getBugReportByClientReportId(input.clientReportId);
    if (existing) {
      return c.json({
        id: existing.id,
        seq: existing.seq,
        status: existing.status,
        alreadySubmitted: true,
      });
    }

    const hourAgo = new Date(deps.now().getTime() - 60 * 60 * 1000).toISOString();
    const recent = await deps.repo.countBugReportsSince(userId, hourAgo);
    if (recent >= BUG_RATE_LIMIT_PER_HOUR) {
      return c.json(
        {
          error: 'rate_limited',
          message: `At most ${BUG_RATE_LIMIT_PER_HOUR} reports per hour`,
        },
        429,
      );
    }

    const row = await deps.repo.insertBugReport({
      userId,
      clientReportId: input.clientReportId,
      description: input.description,
      expectedBehavior: input.expectedBehavior ?? null,
      diagnostic: input.diagnostic,
      appVersion: input.appVersion ?? null,
      buildNumber: input.buildNumber ?? null,
      iosVersion: input.iosVersion ?? null,
      deviceModel: input.deviceModel ?? null,
      appState: input.appState ?? null,
    });

    if (deps.env.nodeEnv !== 'production') {
      console.log(`[bugs] filed BUG-${row.seq} by user=${userId}`);
    }

    return c.json({ id: row.id, seq: row.seq, status: row.status, alreadySubmitted: false }, 201);
  });

  return app;
}
