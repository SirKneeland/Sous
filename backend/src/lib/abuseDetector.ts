// Abuse detection (Project 3, V1).
//
// Runs AFTER a proxied chat request has been recorded. It never blocks the
// current request — V1 abuse handling is a manual review queue, not automated
// blocking. When a threshold is exceeded it sets `users.abuse_flag` (+ reason)
// so the internal admin dashboard can surface the account.
//
// Thresholds come from the `config` table (see schema seed + engineering plan).

import type { Repo } from '../db/repo.js';
import { startOfUtcDay } from './billingPeriod.js';

export interface AbuseConfig {
  recipesPerDay: number;
  recipesPerPeriod: number;
  chatPerRecipe: number;
}

function numberFrom(config: Record<string, string>, key: string, fallback: number): number {
  const raw = config[key];
  if (raw == null) return fallback;
  try {
    const n = Number(JSON.parse(raw));
    return Number.isFinite(n) ? n : fallback;
  } catch {
    const n = Number(raw);
    return Number.isFinite(n) ? n : fallback;
  }
}

export function abuseConfigFrom(config: Record<string, string>): AbuseConfig {
  return {
    recipesPerDay: numberFrom(config, 'abuse_recipes_per_day', 20),
    recipesPerPeriod: numberFrom(config, 'abuse_recipes_per_period', 150),
    chatPerRecipe: numberFrom(config, 'abuse_chat_per_recipe', 200),
  };
}

export interface AbuseCheckArgs {
  repo: Repo;
  config: AbuseConfig;
  userId: string;
  recipeId: string | null;
  billingPeriod: string;
  now?: Date;
}

/**
 * Evaluate abuse signals for a user and flag the account if any threshold is
 * exceeded. Returns the reason string if flagged, else null. Safe to call
 * fire-and-forget; it swallows nothing — callers should `.catch` so a flagging
 * failure can never break the proxied request.
 */
export async function checkAbuse(args: AbuseCheckArgs): Promise<string | null> {
  const { repo, config, userId, recipeId, billingPeriod, now = new Date() } = args;

  const [recipesToday, recipesThisPeriod, chatForRecipe] = await Promise.all([
    repo.countNewRecipesSince(userId, startOfUtcDay(now)),
    repo.getRecipeCapCount(userId, billingPeriod),
    recipeId ? repo.countEventsForRecipe(userId, recipeId) : Promise.resolve(0),
  ]);

  const reasons: string[] = [];
  if (recipesToday > config.recipesPerDay) {
    reasons.push(`${recipesToday} new recipes today (threshold ${config.recipesPerDay})`);
  }
  if (recipesThisPeriod > config.recipesPerPeriod) {
    reasons.push(
      `${recipesThisPeriod} recipes this period (threshold ${config.recipesPerPeriod})`,
    );
  }
  if (recipeId && chatForRecipe > config.chatPerRecipe) {
    reasons.push(
      `${chatForRecipe} requests on one recipe (threshold ${config.chatPerRecipe})`,
    );
  }

  if (reasons.length === 0) return null;

  const reason = reasons.join('; ');
  await repo.setAbuseFlag(userId, reason);
  return reason;
}
