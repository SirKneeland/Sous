// Test harness: build an app wired to a fake repo + a deterministic Apple verifier.

import { createApp } from '../app.js';
import type { AppDeps } from '../types.js';
import type { OpenAIProxy } from '../lib/openai.js';
import { createFakeRepo, type FakeRepoState } from './fakeRepo.js';

export const TEST_JWT_SECRET = 'test-secret-do-not-use-in-production';
export const TEST_ADMIN_KEY = 'test-admin-key';

export interface TestAppOptions {
  /** Fake OpenAI forwarder. Defaults to a stub returning a minimal completion. */
  openai?: OpenAIProxy;
  /** Fixed clock for deterministic billing-period tests. */
  now?: () => Date;
  adminApiKey?: string;
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
    },
    // Deterministic: treat the identity token string as the Apple sub.
    verifyApple: async (identityToken: string) => ({
      sub: identityToken,
      email: `${identityToken}@example.test`,
    }),
    openai: options.openai ?? defaultFakeOpenAI(),
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
