// App-level dependency and Hono context typing.

import type { Repo } from './db/repo.js';
import type { AppleIdentity } from './lib/apple.js';
import type { OpenAIProxy } from './lib/openai.js';

export interface AppEnvConfig {
  nodeEnv: string;
  bypassApple: boolean;
  appleClientId?: string;
  /** Admin API key guarding /admin/* (separate from user session tokens). */
  adminApiKey?: string;
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
  /** Forward chat/TTS to OpenAI. Injectable so tests need no network or key. */
  openai: OpenAIProxy;
  /** Injectable clock for deterministic billing-period / time-window tests. */
  now(): Date;
}

/** Hono generics: variables set by middleware and available to handlers. */
export interface HonoEnv {
  Variables: {
    userId: string;
    deps: AppDeps;
  };
}
