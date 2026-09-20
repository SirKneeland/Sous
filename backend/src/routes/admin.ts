// /api/v1/admin/* — internal, operator-only dashboard (Project 3).
//
// Guarded by a SEPARATE admin API key (env ADMIN_API_KEY), NOT a user session
// token. The key is sent in the `X-Admin-Key` header. There is no user context
// here — this is aggregate, read-only reporting for operator eyes only.

import { Hono, type Context } from 'hono';
import { z } from 'zod';
import type { HonoEnv } from '../types.js';
import {
  BUG_STATUSES,
  TERMINAL_BUG_STATUSES,
  type BugReportRow,
  type BugStatus,
  type BugTriageUpdate,
} from '../db/types.js';
import { computeEntitlement } from '../lib/entitlement.js';
import { entitlementConfigFrom } from '../lib/config.js';
import { currentBillingPeriod } from '../lib/billingPeriod.js';

export function adminRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();

  // Admin-key gate. Uses a constant-time-ish comparison and rejects when no key
  // is configured (fail closed).
  app.use('*', async (c, next) => {
    const deps = c.get('deps');
    const expected = deps.env.adminApiKey;
    const provided = c.req.header('X-Admin-Key') ?? '';
    if (!expected || !safeEqual(provided, expected)) {
      return c.json({ error: 'unauthorized', message: 'Invalid admin key' }, 401);
    }
    await next();
  });

  // GET /admin/dashboard — aggregate usage + cost + abuse snapshot.
  app.get('/dashboard', async (c) => {
    const deps = c.get('deps');
    const now = deps.now();
    const period = currentBillingPeriod(now);

    const [users, subscriptions, rawConfig, events, capCounters] = await Promise.all([
      deps.repo.listAllUsers(),
      deps.repo.listAllSubscriptions(),
      deps.repo.getConfigAll(),
      deps.repo.getUsageEventsForPeriod(period),
      deps.repo.getRecipeCapCountersForPeriod(period),
    ]);

    const config = entitlementConfigFrom(rawConfig);
    const subByUser = new Map(subscriptions.map((s) => [s.user_id, s]));

    // Active users bucketed by computed entitlement (exclude deleted accounts).
    const activeUsers = { trial: 0, paid: 0, byok: 0, softWall: 0 };
    for (const u of users) {
      if (u.is_deleted) continue;
      const ent = computeEntitlement(
        { is_byok_eligible: u.is_byok_eligible },
        subByUser.get(u.id) ?? null,
        config,
        now,
      ).status;
      if (ent === 'byok') activeUsers.byok += 1;
      else if (ent === 'subscriber' || ent === 'grace') activeUsers.paid += 1;
      else if (ent === 'trialing') activeUsers.trial += 1;
      else activeUsers.softWall += 1;
    }

    // Cost this month by modality.
    const byModality = { text: 0, image: 0, voice: 0 };
    let totalUsd = 0;
    let newRecipeEvents = 0;
    let capBlockedEvents = 0;
    const costByUser = new Map<string, number>();
    for (const e of events) {
      const cost = Number(e.estimated_cost_usd ?? 0);
      totalUsd += cost;
      if (e.request_type === 'image') byModality.image += cost;
      else if (e.request_type === 'voice') byModality.voice += cost;
      else byModality.text += cost;
      costByUser.set(e.user_id, (costByUser.get(e.user_id) ?? 0) + cost);
      if (e.is_new_recipe) {
        newRecipeEvents += 1;
        // Cap blocks are recorded as is_new_recipe error events with no model
        // (distinct from upstream OpenAI errors, which carry a model).
        if (e.request_outcome === 'error' && e.model == null) capBlockedEvents += 1;
      }
    }

    const capHitRate = newRecipeEvents > 0 ? round4(capBlockedEvents / newRecipeEvents) : 0;
    const flaggedAccounts = users.filter((u) => u.abuse_flag).length;

    const topUsersByRecipes = [...capCounters]
      .sort((a, b) => b.recipes_used - a.recipes_used)
      .slice(0, 10)
      .map((r) => ({
        userId: r.user_id,
        recipes: r.recipes_used,
        costUsd: round6(costByUser.get(r.user_id) ?? 0),
      }));

    return c.json({
      activeUsers,
      costThisMonth: {
        totalUsd: round6(totalUsd),
        byModality: {
          text: round6(byModality.text),
          image: round6(byModality.image),
          voice: round6(byModality.voice),
        },
      },
      capHitRate,
      flaggedAccounts,
      topUsersByRecipes,
      billingPeriod: period,
    });
  });

  // POST /admin/users/:id/byok-eligible — manually flag an account as BYOK-eligible.
  // Body: { eligible: boolean }. Used for testing and hand-grandfathering.
  app.post('/users/:id/byok-eligible', async (c) => {
    const deps = c.get('deps');
    const userId = c.req.param('id');

    const body = await c.req.json().catch(() => null) as Record<string, unknown> | null;
    if (body == null || typeof body.eligible !== 'boolean') {
      return c.json({ error: 'bad_request', message: 'Expected { eligible: boolean }' }, 400);
    }

    const user = await deps.repo.getUserById(userId);
    if (!user) {
      return c.json({ error: 'not_found', message: 'User not found' }, 404);
    }

    await deps.repo.setByokEligible(userId, body.eligible);
    return c.json({ ok: true, userId, eligible: body.eligible });
  });

  // -------------------------------------------------------------------------
  // Bug triage (see docs/BugTriage.md, backend/scripts/bugs.sh)
  //
  // Reports are never deleted — there is deliberately no DELETE route. Triage
  // changes `status`; a fixed report stays as regression-test source material.
  // -------------------------------------------------------------------------

  /** Resolve ":ref" — either a short number ("17") or a full uuid. */
  async function findBugByRef(
    c: Context<HonoEnv>,
    ref: string,
  ): Promise<BugReportRow | null> {
    const deps = c.get('deps');
    return /^\d+$/.test(ref)
      ? deps.repo.getBugReportBySeq(Number(ref))
      : deps.repo.getBugReportById(ref);
  }

  // GET /admin/bugs?status=new&limit=50 — triage list, no diagnostic blobs.
  app.get('/bugs', async (c) => {
    const deps = c.get('deps');

    const statusParam = c.req.query('status');
    if (statusParam && !BUG_STATUSES.includes(statusParam as BugStatus)) {
      return c.json(
        { error: 'bad_request', message: `status must be one of: ${BUG_STATUSES.join(', ')}` },
        400,
      );
    }

    const limitParam = Number(c.req.query('limit') ?? '50');
    const limit = Number.isFinite(limitParam)
      ? Math.min(Math.max(Math.trunc(limitParam), 1), 200)
      : 50;

    const bugs = await deps.repo.listBugReports({
      status: statusParam as BugStatus | undefined,
      limit,
    });
    return c.json({ bugs, count: bugs.length });
  });

  // GET /admin/bugs/:ref — one full report, diagnostic included.
  app.get('/bugs/:ref', async (c) => {
    const bug = await findBugByRef(c, c.req.param('ref'));
    if (!bug) return c.json({ error: 'not_found', message: 'Bug report not found' }, 404);
    return c.json(bug);
  });

  // PATCH /admin/bugs/:ref — apply triage. Omitted fields are left untouched.
  app.patch('/bugs/:ref', async (c) => {
    const deps = c.get('deps');

    const bug = await findBugByRef(c, c.req.param('ref'));
    if (!bug) return c.json({ error: 'not_found', message: 'Bug report not found' }, 404);

    const raw = await c.req.json().catch(() => null);
    const parsed = triageSchema.safeParse(raw);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      const where = issue?.path.join('.') || 'body';
      return c.json(
        { error: 'bad_request', message: `${where}: ${issue?.message ?? 'invalid'}` },
        400,
      );
    }

    const update: BugTriageUpdate = { ...parsed.data };

    // Closing a report stamps resolved_at; reopening clears it. Doing this here
    // rather than in the DB keeps the timestamp consistent with the injected clock.
    if (update.status !== undefined) {
      const isTerminal = (TERMINAL_BUG_STATUSES as readonly string[]).includes(update.status);
      update.resolvedAt = isTerminal ? (bug.resolved_at ?? deps.now().toISOString()) : null;
    }

    if (update.duplicateOf === bug.id) {
      return c.json({ error: 'bad_request', message: 'A report cannot duplicate itself' }, 400);
    }

    const updated = await deps.repo.updateBugReportTriage(bug.id, update);
    return c.json(updated);
  });

  return app;
}

const triageSchema = z
  .object({
    status: z.enum(BUG_STATUSES).optional(),
    triageNotes: z.string().max(10_000).nullable().optional(),
    resolution: z.string().max(10_000).nullable().optional(),
    duplicateOf: z.string().uuid().nullable().optional(),
    tags: z.array(z.string().max(64)).max(20).optional(),
  })
  .refine((o) => Object.keys(o).length > 0, {
    message: 'expected at least one field to change',
  });

function round4(n: number): number {
  return Math.round(n * 1e4) / 1e4;
}

function round6(n: number): number {
  return Math.round(n * 1e6) / 1e6;
}

/** Length-aware constant-time string comparison. */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
