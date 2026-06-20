// Integration tests for /api/v1/subscription/* (validate + notify + grace).
// Run: cd backend && npm test
//
// These drive the route logic with the harness's fake App Store verifier
// (defaultFakeAppStore), which treats the "receipt"/"signedPayload" string as
// JSON. The real cryptographic verifier (lib/appstore.ts) is injected only in
// production; here we cover the route behaviour deterministically with no keys.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTestApp, signInWithApple, readJson } from '../test/harness.js';

const ORIG_TXN = 'orig-txn-123';

function isoIn(days: number): string {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
}

async function authedToken(app: ReturnType<typeof buildTestApp>['app'], sub: string) {
  const { body } = await signInWithApple(app, sub);
  return body.token as string;
}

/** Build a fake StoreKit "receipt" (JSON the fake verifier parses). */
function receipt(fields: Record<string, unknown>): string {
  return JSON.stringify({ originalTransactionId: ORIG_TXN, ...fields });
}

async function validate(
  app: ReturnType<typeof buildTestApp>['app'],
  token: string,
  receiptData: string,
) {
  return app.request('/api/v1/subscription/validate', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ receiptData }),
  });
}

async function notify(
  app: ReturnType<typeof buildTestApp>['app'],
  signedPayload: string,
  opts: { secret?: string } = {},
) {
  const path = opts.secret
    ? `/api/v1/subscription/notify?secret=${encodeURIComponent(opts.secret)}`
    : '/api/v1/subscription/notify';
  return app.request(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ signedPayload }),
  });
}

// ---------------------------------------------------------------------------
// validate
// ---------------------------------------------------------------------------

test('validate: a valid receipt activates the subscription and returns subscriber', async () => {
  const { app, state } = buildTestApp();
  const token = await authedToken(app, 'apple-sub-validate-1');

  const res = await validate(
    app,
    token,
    receipt({ environment: 'Production', purchaseDate: isoIn(0), expiresDate: isoIn(30) }),
  );
  assert.equal(res.status, 200);
  const body = await readJson(res);

  assert.equal(body.entitlement.status, 'subscriber');
  assert.equal(body.subscription.status, 'active');
  assert.equal(body.subscription.apple_original_transaction_id, ORIG_TXN);

  const sub = state.subscriptions[0]!;
  assert.equal(sub.status, 'active');
  assert.equal(sub.apple_original_transaction_id, ORIG_TXN);
  assert.ok(sub.current_period_end);
});

test('validate: a sandbox receipt activates the subscription gracefully', async () => {
  const { app } = buildTestApp();
  const token = await authedToken(app, 'apple-sub-validate-sandbox');

  const res = await validate(
    app,
    token,
    receipt({ environment: 'Sandbox', purchaseDate: isoIn(0), expiresDate: isoIn(30) }),
  );
  assert.equal(res.status, 200);
  const body = await readJson(res);
  assert.equal(body.entitlement.status, 'subscriber');
  assert.equal(body.subscription.status, 'active');
});

test('validate: an invalid receipt is rejected and does not change status', async () => {
  const { app, state } = buildTestApp();
  const token = await authedToken(app, 'apple-sub-validate-bad');

  const res = await validate(app, token, 'invalid');
  assert.equal(res.status, 400);
  const body = await readJson(res);
  assert.equal(body.error, 'invalid_receipt');
  // Still a trial subscription — never activated.
  assert.equal(state.subscriptions[0]!.status, 'trialing');
});

test('validate: a revoked transaction does not grant access', async () => {
  const { app } = buildTestApp();
  const token = await authedToken(app, 'apple-sub-validate-revoked');

  const res = await validate(
    app,
    token,
    receipt({ expiresDate: isoIn(30), revocationDate: isoIn(-1) }),
  );
  assert.equal(res.status, 400);
  const body = await readJson(res);
  assert.equal(body.error, 'invalid_receipt');
});

test('validate: a transaction already linked to another account is refused', async () => {
  const { app } = buildTestApp();
  // User A validates and claims ORIG_TXN.
  const tokenA = await authedToken(app, 'apple-validate-ownerA');
  const a = await validate(app, tokenA, receipt({ expiresDate: isoIn(30) }));
  assert.equal(a.status, 200);

  // User B tries to reuse the same signed transaction.
  const tokenB = await authedToken(app, 'apple-validate-ownerB');
  const b = await validate(app, tokenB, receipt({ expiresDate: isoIn(30) }));
  assert.equal(b.status, 409);
  const body = await readJson(b);
  assert.equal(body.error, 'transaction_already_claimed');
});

test('validate: re-validating my own transaction still succeeds (idempotent)', async () => {
  const { app } = buildTestApp();
  const token = await authedToken(app, 'apple-validate-idem');
  assert.equal((await validate(app, token, receipt({ expiresDate: isoIn(30) }))).status, 200);
  // Restore / re-validate by the same owner is fine.
  assert.equal((await validate(app, token, receipt({ expiresDate: isoIn(30) }))).status, 200);
});

test('validate: requires auth', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/api/v1/subscription/validate', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ receiptData: receipt({ expiresDate: isoIn(30) }) }),
  });
  assert.equal(res.status, 401);
});

// ---------------------------------------------------------------------------
// notify (App Store Server Notifications v2)
// ---------------------------------------------------------------------------

/** Sign in, activate via validate, and return the token (sub now has ORIG_TXN). */
async function activatedUser(app: ReturnType<typeof buildTestApp>['app'], sub: string) {
  const token = await authedToken(app, sub);
  await validate(app, token, receipt({ expiresDate: isoIn(30) }));
  return token;
}

function notification(type: string, txnFields: Record<string, unknown> = {}): string {
  return JSON.stringify({
    notificationType: type,
    transaction: { originalTransactionId: ORIG_TXN, ...txnFields },
  });
}

test('notify: SUBSCRIBED sets status active', async () => {
  const { app, state } = buildTestApp();
  await activatedUser(app, 'apple-notify-subscribed');
  // Force a non-active starting point to prove the transition.
  state.subscriptions[0]!.status = 'lapsed';

  const res = await notify(app, notification('SUBSCRIBED', { expiresDate: isoIn(30) }));
  assert.equal(res.status, 200);
  assert.equal(state.subscriptions[0]!.status, 'active');
});

test('notify: DID_RENEW updates current_period_end and stays active', async () => {
  const { app, state } = buildTestApp();
  await activatedUser(app, 'apple-notify-renew');
  const newEnd = isoIn(60);

  const res = await notify(app, notification('DID_RENEW', { expiresDate: newEnd }));
  assert.equal(res.status, 200);
  assert.equal(state.subscriptions[0]!.status, 'active');
  assert.equal(state.subscriptions[0]!.current_period_end, newEnd);
});

test('notify: EXPIRED sets status lapsed', async () => {
  const { app, state } = buildTestApp();
  await activatedUser(app, 'apple-notify-expired');

  const res = await notify(app, notification('EXPIRED', { expiresDate: isoIn(-1) }));
  assert.equal(res.status, 200);
  assert.equal(state.subscriptions[0]!.status, 'lapsed');
});

test('notify: DID_FAIL_TO_RENEW sets lapsed and entitlement enters grace', async () => {
  const { app } = buildTestApp();
  const token = await activatedUser(app, 'apple-notify-fail');

  // Billing just failed: period ended ~now, grace runs 7 days from there.
  const res = await notify(app, notification('DID_FAIL_TO_RENEW', { expiresDate: isoIn(-1) }));
  assert.equal(res.status, 200);

  const status = await readJson(
    await app.request('/api/v1/subscription/status', {
      headers: { Authorization: `Bearer ${token}` },
    }),
  );
  assert.equal(status.subscription.status, 'lapsed');
  assert.equal(status.entitlement.status, 'grace');
});

test('grace expires to soft_wall after 7 days', async () => {
  const { app } = buildTestApp();
  const token = await activatedUser(app, 'apple-notify-grace-expired');

  // Period ended 10 days ago → grace (period_end + 7) is already over.
  await notify(app, notification('DID_FAIL_TO_RENEW', { expiresDate: isoIn(-10) }));

  const status = await readJson(
    await app.request('/api/v1/subscription/status', {
      headers: { Authorization: `Bearer ${token}` },
    }),
  );
  assert.equal(status.entitlement.status, 'soft_wall');
});

test('notify: REFUND drops the user to soft_wall', async () => {
  const { app, state } = buildTestApp();
  await activatedUser(app, 'apple-notify-refund');

  const res = await notify(app, notification('REFUND'));
  assert.equal(res.status, 200);
  assert.equal(state.subscriptions[0]!.status, 'soft_wall');
});

test('notify: REVOKE drops the user to soft_wall', async () => {
  const { app, state } = buildTestApp();
  await activatedUser(app, 'apple-notify-revoke');

  const res = await notify(app, notification('REVOKE'));
  assert.equal(res.status, 200);
  assert.equal(state.subscriptions[0]!.status, 'soft_wall');
});

test('notify: an unhandled type is acknowledged without changing status', async () => {
  const { app, state } = buildTestApp();
  await activatedUser(app, 'apple-notify-other');
  state.subscriptions[0]!.status = 'active';

  const res = await notify(app, notification('PRICE_INCREASE'));
  assert.equal(res.status, 200);
  assert.equal(state.subscriptions[0]!.status, 'active');
});

test('notify: an unknown original transaction id is acknowledged (no row to update)', async () => {
  const { app } = buildTestApp();
  // No validate call → no subscription carries ORIG_TXN.
  const res = await notify(app, notification('DID_RENEW', { expiresDate: isoIn(30) }));
  assert.equal(res.status, 200);
  const body = await readJson(res);
  assert.equal(body.ok, true);
});

test('notify: an unverifiable payload is rejected', async () => {
  const { app } = buildTestApp();
  const res = await notify(app, 'invalid');
  assert.equal(res.status, 400);
  const body = await readJson(res);
  assert.equal(body.error, 'invalid_signature');
});

test('notify: shared-secret gate rejects a missing/incorrect secret', async () => {
  const { app } = buildTestApp({}, { appStoreNotificationSecret: 'top-secret' });
  await activatedUser(app, 'apple-notify-secret');

  // Wrong secret → 401.
  const bad = await notify(app, notification('DID_RENEW', { expiresDate: isoIn(30) }), {
    secret: 'wrong',
  });
  assert.equal(bad.status, 401);

  // Correct secret → 200.
  const good = await notify(app, notification('DID_RENEW', { expiresDate: isoIn(30) }), {
    secret: 'top-secret',
  });
  assert.equal(good.status, 200);
});
