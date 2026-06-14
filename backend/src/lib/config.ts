// Helpers for working with the `config` table. Values are stored as
// JSON-serialized strings (e.g. "14", "false", "null"), so reading them means
// JSON.parse with a typed fallback.

import type { EntitlementConfig } from './entitlement.js';

/** Parse every config value from its JSON string form into a flat object. */
export function parseConfig(raw: Record<string, string>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(raw)) {
    try {
      out[key] = JSON.parse(value);
    } catch {
      // Tolerate plain (non-JSON) strings.
      out[key] = value;
    }
  }
  return out;
}

function numberFrom(raw: Record<string, string>, key: string, fallback: number): number {
  const v = raw[key];
  if (v == null) return fallback;
  const n = Number(JSON.parse(v));
  return Number.isFinite(n) ? n : fallback;
}

export function trialDurationDays(raw: Record<string, string>): number {
  return numberFrom(raw, 'trial_duration_days', 14);
}

export function trialRecipeCap(raw: Record<string, string>): number {
  return numberFrom(raw, 'trial_recipe_cap', 14);
}

export function paidRecipeCap(raw: Record<string, string>): number {
  return numberFrom(raw, 'paid_recipe_cap', 100);
}

export function entitlementConfigFrom(raw: Record<string, string>): EntitlementConfig {
  return { trialRecipeCap: trialRecipeCap(raw) };
}
