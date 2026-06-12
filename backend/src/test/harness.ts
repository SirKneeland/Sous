// Test harness: build an app wired to a fake repo + a deterministic Apple verifier.

import { createApp } from '../app.js';
import type { AppDeps } from '../types.js';
import { createFakeRepo, type FakeRepoState } from './fakeRepo.js';

export const TEST_JWT_SECRET = 'test-secret-do-not-use-in-production';

export function buildTestApp(overrides: Partial<FakeRepoState> = {}) {
  const { repo, state } = createFakeRepo(overrides);

  const deps: AppDeps = {
    repo,
    jwtSecret: TEST_JWT_SECRET,
    env: { nodeEnv: 'test', bypassApple: true, appleClientId: undefined },
    // Deterministic: treat the identity token string as the Apple sub.
    verifyApple: async (identityToken: string) => ({
      sub: identityToken,
      email: `${identityToken}@example.test`,
    }),
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
