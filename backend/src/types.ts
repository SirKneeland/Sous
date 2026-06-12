// App-level dependency and Hono context typing.

import type { Repo } from './db/repo.js';
import type { AppleIdentity } from './lib/apple.js';

export interface AppEnvConfig {
  nodeEnv: string;
  bypassApple: boolean;
  appleClientId?: string;
}

/**
 * Everything the route handlers need, injected at app construction. Tests build
 * this with a fake repo and a fake verifyApple; production builds it from env.
 */
export interface AppDeps {
  repo: Repo;
  jwtSecret: string;
  env: AppEnvConfig;
  /** Verify an Apple identity token → identity. Injectable for tests. */
  verifyApple(identityToken: string): Promise<AppleIdentity>;
}

/** Hono generics: variables set by middleware and available to handlers. */
export interface HonoEnv {
  Variables: {
    userId: string;
    deps: AppDeps;
  };
}
