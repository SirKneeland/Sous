// Test harness: build an app wired to a fake repo + a deterministic Apple verifier.

import { createApp } from '../app.js';
import type { AppDeps } from '../types.js';
import type { OpenAIProxy } from '../lib/openai.js';
import type {
  AppStoreVerifier,
  VerifiedTransaction,
  DecodedNotification,
} from '../lib/appstore.js';
import { createFakeRepo, type FakeRepoState } from './fakeRepo.js';

export const TEST_JWT_SECRET = 'test-secret-do-not-use-in-production';
export const TEST_ADMIN_KEY = 'test-admin-key';
export const TEST_DELETION_HASH_SECRET = 'test-deletion-hash-secret';

export interface TestAppOptions {
  /** Fake OpenAI forwarder. Defaults to a stub returning a minimal completion. */
  openai?: OpenAIProxy;
  /** Fake App Store verifier. Defaults to one treating the JWS string as JSON. */
  appstore?: AppStoreVerifier;
  /** Fixed clock for deterministic billing-period tests. */
  now?: () => Date;
  adminApiKey?: string;
  appStoreNotificationSecret?: string;
}

/**
 * Default fake App Store verifier for tests. It does NO crypto: it parses the
 * supplied "JWS" string as JSON and shapes it into a VerifiedTransaction /
 * DecodedNotification. A string `"invalid"` (or anything non-JSON) throws, so
 * tests can exercise the rejection path. This keeps subscription route tests free
 * of Apple keys and certificate chains while still covering the route logic.
 */
export function defaultFakeAppStore(): AppStoreVerifier {
  const txn = (o: Record<string, unknown>): VerifiedTransaction => ({
    transactionId: String(o.transactionId ?? 'txn-1'),
    originalTransactionId: String(o.originalTransactionId ?? 'orig-1'),
    bundleId: String(o.bundleId ?? 'com.donutindustries.SousApp'),
    productId: String(o.productId ?? 'com.donutindustries.SousApp.pro.monthly'),
    purchaseDate: String(o.purchaseDate ?? new Date().toISOString()),
    expiresDate: (o.expiresDate as string | null) ?? null,
    revocationDate: (o.revocationDate as string | null) ?? null,
    environment: String(o.environment ?? 'Production'),
  });
  function parse(jws: string): Record<string, unknown> {
    if (jws === 'invalid') throw new Error('invalid receipt');
    try {
      return JSON.parse(jws) as Record<string, unknown>;
    } catch {
      throw new Error('malformed receipt');
    }
  }
  return {
    async verifyTransaction(jws) {
      return txn(parse(jws));
    },
    async verifyNotification(jws) {
      const o = parse(jws);
      const n: DecodedNotification = {
        notificationType: String(o.notificationType ?? ''),
        subtype: (o.subtype as string | null) ?? null,
        notificationUUID: (o.notificationUUID as string | null) ?? null,
        bundleId: (o.bundleId as string | null) ?? 'com.donutindustries.SousApp',
        environment: (o.environment as string | null) ?? 'Production',
        transaction: o.transaction ? txn(o.transaction as Record<string, unknown>) : null,
      };
      return n;
    },
  };
}

/** Default fake forwarder: a non-streaming completion with token usage. */
export function defaultFakeOpenAI(): OpenAIProxy {
  const completion = {
    id: 'chatcmpl-test',
    object: 'chat.completion',
    choices: [{ message: { role: 'assistant', content: '{"assistant_message":"ok"}' } }],
    usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 },
  };
  return {
    async forwardChat() {
      return new Response(JSON.stringify(completion), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    },
    async forwardTTS() {
      return new Response(new Uint8Array([1, 2, 3]), {
        status: 200,
        headers: { 'Content-Type': 'audio/mpeg' },
      });
    },
  };
}

export function buildTestApp(
  overrides: Partial<FakeRepoState> = {},
  options: TestAppOptions = {},
) {
  const { repo, state } = createFakeRepo(overrides);

  const deps: AppDeps = {
    repo,
    jwtSecret: TEST_JWT_SECRET,
    env: {
      nodeEnv: 'test',
      bypassApple: true,
      appleClientId: undefined,
      adminApiKey: options.adminApiKey ?? TEST_ADMIN_KEY,
      appStoreNotificationSecret: options.appStoreNotificationSecret,
      accountDeletionHashSecret: TEST_DELETION_HASH_SECRET,
    },
    // Deterministic: treat the identity token string as the Apple sub.
    verifyApple: async (identityToken: string) => ({
      sub: identityToken,
      email: `${identityToken}@example.test`,
    }),
    openai: options.openai ?? defaultFakeOpenAI(),
    appstore: options.appstore ?? defaultFakeAppStore(),
    now: options.now ?? (() => new Date()),
  };

  const app = createApp(deps);
  return { app, deps, state, repo };
}

/** Read a Response body as JSON, loosely typed for test assertions. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function readJson(res: Response): Promise<any> {
  return res.json();
}

/** Helper: POST /api/v1/auth/apple and return the parsed JSON body + status. */
export async function signInWithApple(
  app: ReturnType<typeof buildTestApp>['app'],
  identityToken: string,
  referralCode?: string,
) {
  const res = await app.request('/api/v1/auth/apple', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ identityToken, ...(referralCode ? { referralCode } : {}) }),
  });
  const body = await readJson(res);
  return { res, body };
}
