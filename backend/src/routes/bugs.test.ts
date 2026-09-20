// Integration tests for in-app bug submission and operator triage.
// Run: cd backend && npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { buildTestApp, signInWithApple, readJson, TEST_ADMIN_KEY } from '../test/harness.js';
import { MAX_DIAGNOSTIC_CHARS, BUG_RATE_LIMIT_PER_HOUR } from './bugs.js';

/** A minimal but realistic submission body. */
function submission(overrides: Record<string, unknown> = {}) {
  return {
    clientReportId: randomUUID(),
    description: 'Steps re-ordered themselves after I accepted a patch',
    expectedBehavior: 'Step order should stay as written',
    diagnostic: '# Sous Debug Diagnostic\n\n## 1. Export Metadata\n\n- **App State:** cooking',
    appVersion: '1.2.0',
    buildNumber: '142',
    iosVersion: '18.2',
    deviceModel: 'iPhone16,1',
    appState: 'cooking (recipe canvas active)',
    ...overrides,
  };
}

async function signedInToken(app: ReturnType<typeof buildTestApp>['app'], sub = 'apple-bug-1') {
  const { body } = await signInWithApple(app, sub);
  return body.token as string;
}

function submit(
  app: ReturnType<typeof buildTestApp>['app'],
  token: string,
  body: Record<string, unknown>,
) {
  return app.request('/api/v1/bugs', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}

const adminHeaders = { 'X-Admin-Key': TEST_ADMIN_KEY };

// ---------------------------------------------------------------------------
// Submission
// ---------------------------------------------------------------------------

test('bugs: submission requires authentication', async () => {
  const { app } = buildTestApp();
  const res = await app.request('/api/v1/bugs', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(submission()),
  });
  assert.equal(res.status, 401);
});

test('bugs: stores a report and returns its short number', async () => {
  const { app, state } = buildTestApp();
  const token = await signedInToken(app);

  const res = await submit(app, token, submission());
  assert.equal(res.status, 201);

  const body = await readJson(res);
  assert.equal(body.seq, 1);
  assert.equal(body.status, 'new');
  assert.equal(body.alreadySubmitted, false);

  assert.equal(state.bugReports.length, 1);
  const stored = state.bugReports[0]!;
  assert.equal(stored.description, 'Steps re-ordered themselves after I accepted a patch');
  assert.equal(stored.expected_behavior, 'Step order should stay as written');
  assert.match(stored.diagnostic, /Sous Debug Diagnostic/);
  assert.equal(stored.app_version, '1.2.0');
  assert.equal(stored.build_number, '142');
  assert.equal(stored.ios_version, '18.2');
  assert.equal(stored.device_model, 'iPhone16,1');
  assert.equal(stored.resolved_at, null);
  assert.deepEqual(stored.tags, []);
});

test('bugs: an empty description is rejected', async () => {
  const { app, state } = buildTestApp();
  const token = await signedInToken(app);

  const res = await submit(app, token, submission({ description: '   ' }));
  assert.equal(res.status, 400);
  assert.equal(state.bugReports.length, 0);
});

test('bugs: a missing diagnostic is rejected', async () => {
  const { app, state } = buildTestApp();
  const token = await signedInToken(app);

  const res = await submit(app, token, submission({ diagnostic: '' }));
  assert.equal(res.status, 400);
  assert.equal(state.bugReports.length, 0);
});

test('bugs: an oversized diagnostic is rejected with 413', async () => {
  const { app, state } = buildTestApp();
  const token = await signedInToken(app);

  const res = await submit(
    app,
    token,
    submission({ diagnostic: 'x'.repeat(MAX_DIAGNOSTIC_CHARS + 1) }),
  );
  assert.equal(res.status, 413);
  const body = await readJson(res);
  assert.equal(body.error, 'payload_too_large');
  assert.equal(state.bugReports.length, 0);
});

test('bugs: resubmitting the same clientReportId does not duplicate the report', async () => {
  const { app, state } = buildTestApp();
  const token = await signedInToken(app);
  const payload = submission();

  const first = await submit(app, token, payload);
  assert.equal(first.status, 201);
  const firstBody = await readJson(first);

  // Same id again — the client retrying after a timeout it never saw resolve.
  const second = await submit(app, token, payload);
  assert.equal(second.status, 200);
  const secondBody = await readJson(second);

  assert.equal(secondBody.alreadySubmitted, true);
  assert.equal(secondBody.id, firstBody.id);
  assert.equal(secondBody.seq, firstBody.seq);
  assert.equal(state.bugReports.length, 1);
});

test('bugs: a stuck client is rate limited after the hourly ceiling', async () => {
  const { app, state } = buildTestApp();
  const token = await signedInToken(app);

  for (let i = 0; i < BUG_RATE_LIMIT_PER_HOUR; i++) {
    const res = await submit(app, token, submission());
    assert.equal(res.status, 201, `submission ${i} should succeed`);
  }

  const blocked = await submit(app, token, submission());
  assert.equal(blocked.status, 429);
  assert.equal(state.bugReports.length, BUG_RATE_LIMIT_PER_HOUR);
});

test('bugs: reports get consecutive short numbers', async () => {
  const { app } = buildTestApp();
  const token = await signedInToken(app);

  const first = await readJson(await submit(app, token, submission()));
  const second = await readJson(await submit(app, token, submission()));
  assert.equal(first.seq, 1);
  assert.equal(second.seq, 2);
});

// ---------------------------------------------------------------------------
// Admin triage
// ---------------------------------------------------------------------------

test('admin/bugs: rejects a missing or wrong admin key', async () => {
  const { app } = buildTestApp();

  assert.equal((await app.request('/api/v1/admin/bugs')).status, 401);
  assert.equal(
    (await app.request('/api/v1/admin/bugs', { headers: { 'X-Admin-Key': 'nope' } })).status,
    401,
  );
});

test('admin/bugs: a user session token cannot read the backlog', async () => {
  const { app } = buildTestApp();
  const token = await signedInToken(app);

  const res = await app.request('/api/v1/admin/bugs', {
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(res.status, 401);
});

test('admin/bugs: lists reports without the diagnostic blob', async () => {
  const { app } = buildTestApp();
  const token = await signedInToken(app);
  await submit(app, token, submission());

  const res = await app.request('/api/v1/admin/bugs', { headers: adminHeaders });
  assert.equal(res.status, 200);

  const body = await readJson(res);
  assert.equal(body.count, 1);
  assert.equal(body.bugs[0].description, 'Steps re-ordered themselves after I accepted a patch');
  // The blob is deliberately absent — listing twenty bugs must not ship twenty transcripts.
  assert.equal(body.bugs[0].diagnostic, undefined);
});

test('admin/bugs: filters by status and rejects an unknown one', async () => {
  const { app } = buildTestApp();
  const token = await signedInToken(app);
  await submit(app, token, submission());

  const newOnes = await readJson(
    await app.request('/api/v1/admin/bugs?status=new', { headers: adminHeaders }),
  );
  assert.equal(newOnes.count, 1);

  const fixedOnes = await readJson(
    await app.request('/api/v1/admin/bugs?status=fixed', { headers: adminHeaders }),
  );
  assert.equal(fixedOnes.count, 0);

  const bad = await app.request('/api/v1/admin/bugs?status=banana', { headers: adminHeaders });
  assert.equal(bad.status, 400);
});

test('admin/bugs: fetches one full report by short number or uuid', async () => {
  const { app } = buildTestApp();
  const token = await signedInToken(app);
  const filed = await readJson(await submit(app, token, submission()));

  const bySeq = await readJson(
    await app.request('/api/v1/admin/bugs/1', { headers: adminHeaders }),
  );
  assert.equal(bySeq.id, filed.id);
  assert.match(bySeq.diagnostic, /Sous Debug Diagnostic/);

  const byId = await readJson(
    await app.request(`/api/v1/admin/bugs/${filed.id}`, { headers: adminHeaders }),
  );
  assert.equal(byId.seq, 1);

  const missing = await app.request('/api/v1/admin/bugs/999', { headers: adminHeaders });
  assert.equal(missing.status, 404);
});

test('admin/bugs: triage updates status and notes, and stamps resolved_at when closed', async () => {
  const fixedNow = new Date('2026-03-04T12:00:00.000Z');
  const { app } = buildTestApp({}, { now: () => fixedNow });
  const token = await signedInToken(app);
  await submit(app, token, submission());

  const triaged = await readJson(
    await app.request('/api/v1/admin/bugs/1', {
      method: 'PATCH',
      headers: { ...adminHeaders, 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'triaged', triageNotes: 'Repro on build 142', tags: ['patching'] }),
    }),
  );
  assert.equal(triaged.status, 'triaged');
  assert.equal(triaged.triage_notes, 'Repro on build 142');
  assert.deepEqual(triaged.tags, ['patching']);
  // Not closed yet, so no resolution timestamp.
  assert.equal(triaged.resolved_at, null);

  const fixed = await readJson(
    await app.request('/api/v1/admin/bugs/1', {
      method: 'PATCH',
      headers: { ...adminHeaders, 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'fixed', resolution: 'PatchApplier ordering fix' }),
    }),
  );
  assert.equal(fixed.status, 'fixed');
  assert.equal(fixed.resolution, 'PatchApplier ordering fix');
  assert.equal(fixed.resolved_at, fixedNow.toISOString());
  // Earlier triage notes survive an update that does not mention them.
  assert.equal(fixed.triage_notes, 'Repro on build 142');
});

test('admin/bugs: reopening a closed report clears resolved_at', async () => {
  const { app } = buildTestApp();
  const token = await signedInToken(app);
  await submit(app, token, submission());

  await app.request('/api/v1/admin/bugs/1', {
    method: 'PATCH',
    headers: { ...adminHeaders, 'content-type': 'application/json' },
    body: JSON.stringify({ status: 'fixed' }),
  });
  const reopened = await readJson(
    await app.request('/api/v1/admin/bugs/1', {
      method: 'PATCH',
      headers: { ...adminHeaders, 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'in_progress' }),
    }),
  );
  assert.equal(reopened.status, 'in_progress');
  assert.equal(reopened.resolved_at, null);
});

test('admin/bugs: triage rejects an empty body and a self-referential duplicate', async () => {
  const { app } = buildTestApp();
  const token = await signedInToken(app);
  const filed = await readJson(await submit(app, token, submission()));

  const empty = await app.request('/api/v1/admin/bugs/1', {
    method: 'PATCH',
    headers: { ...adminHeaders, 'content-type': 'application/json' },
    body: JSON.stringify({}),
  });
  assert.equal(empty.status, 400);

  const selfDupe = await app.request('/api/v1/admin/bugs/1', {
    method: 'PATCH',
    headers: { ...adminHeaders, 'content-type': 'application/json' },
    body: JSON.stringify({ duplicateOf: filed.id }),
  });
  assert.equal(selfDupe.status, 400);
});

test('admin/bugs: a resolved report is kept, never removed', async () => {
  const { app, state } = buildTestApp();
  const token = await signedInToken(app);
  await submit(app, token, submission());

  await app.request('/api/v1/admin/bugs/1', {
    method: 'PATCH',
    headers: { ...adminHeaders, 'content-type': 'application/json' },
    body: JSON.stringify({ status: 'fixed', resolution: 'done' }),
  });

  // The row survives triage: still one report, still holding its diagnostic.
  assert.equal(state.bugReports.length, 1);
  assert.match(state.bugReports[0]!.diagnostic, /Sous Debug Diagnostic/);

  // And there is no delete route to remove it with.
  const del = await app.request('/api/v1/admin/bugs/1', {
    method: 'DELETE',
    headers: adminHeaders,
  });
  assert.equal(del.status, 404);
});
