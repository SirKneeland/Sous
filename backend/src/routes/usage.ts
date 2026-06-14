// /api/v1/usage/* — recipe-count telemetry + usage summary (Project 3).

import { Hono } from 'hono';
import type { HonoEnv } from '../types.js';
import { authMiddleware } from '../middleware/auth.js';
import { resolveAccess } from '../lib/access.js';
import { paidRecipeCap, trialRecipeCap } from '../lib/config.js';
import { currentBillingPeriod, daysUntilPeriodReset } from '../lib/billingPeriod.js';

/** Whole days remaining until an ISO timestamp; null if absent, clamped to >= 0. */
function daysUntil(iso: string | null, now: Date): number | null {
  if (!iso) return null;
  const ms = new Date(iso).getTime() - now.getTime();
  return Math.max(0, Math.ceil(ms / (24 * 60 * 60 * 1000)));
}

export function usageRoutes(): Hono<HonoEnv> {
  const app = new Hono<HonoEnv>();
  app.use('*', authMiddleware);

  // POST /usage/recipe — record a new recipe for users who bypass the proxy
  // (BYOK). Increments the period counter (uncapped) and returns the new count.
  app.post('/recipe', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const period = currentBillingPeriod(deps.now());
    const recipesUsed = await deps.repo.incrementRecipeCapCounter(userId, period);
    return c.json({ recipesUsed, billingPeriod: period });
  });

  // POST /usage/request — record a non-recipe request (chat/voice turn) for
  // BYOK clients. Lightweight: no body required, no cap. Returns ok.
  app.post('/request', async (c) => {
    return c.json({ ok: true });
  });

  // GET /usage/summary — current billing-period usage for the Settings screen.
  app.get('/summary', async (c) => {
    const deps = c.get('deps');
    const userId = c.get('userId');
    const now = deps.now();
    const period = currentBillingPeriod(now);

    const access = await resolveAccess(deps, userId);
    if (!access) return c.json({ error: 'not_found', message: 'User not found' }, 404);

    const recipesUsed = await deps.repo.getRecipeCapCount(userId, period);
    const recipeCap = paidRecipeCap(access.rawConfig);
    const status = access.entitlement.status;

    const summary: Record<string, unknown> = {
      recipesUsed,
      recipeCap,
      billingPeriod: period,
      resetsInDays: daysUntilPeriodReset(now),
      entitlement: status,
    };

    // Trial users also see trial-specific counts.
    if (status === 'trialing') {
      summary.trialRecipesUsed = access.subscription?.trial_recipes_used ?? 0;
      summary.trialRecipeCap = trialRecipeCap(access.rawConfig);
      summary.trialDaysRemaining =
        daysUntil(access.subscription?.trial_ends_at ?? null, now) ?? 0;
    }

    return c.json(summary);
  });

  return app;
}
