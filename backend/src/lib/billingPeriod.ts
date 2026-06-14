// Billing period helpers. A billing period is an ISO month string, "YYYY-MM",
// matching usage_events.billing_period and recipe_cap_counters.billing_period.

/** Current billing period as "YYYY-MM" (UTC). */
export function currentBillingPeriod(now: Date = new Date()): string {
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

/** Whole days remaining until the first of next month (UTC). Always >= 0. */
export function daysUntilPeriodReset(now: Date = new Date()): number {
  const nextMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
  const ms = nextMonth.getTime() - now.getTime();
  return Math.max(0, Math.ceil(ms / (24 * 60 * 60 * 1000)));
}

/** Start-of-day (UTC) ISO timestamp for the given moment. Used for daily windows. */
export function startOfUtcDay(now: Date = new Date()): string {
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  ).toISOString();
}
