// Production entry point. Loads env, builds real dependencies, serves on PORT.

import { serve } from '@hono/node-server';
import { createApp } from './app.js';
import { createSupabaseClient } from './db/client.js';
import { createSupabaseRepo } from './db/supabaseRepo.js';
import { verifyAppleIdentityToken } from './lib/apple.js';
import { createOpenAIProxy } from './lib/openai.js';
import type { AppDeps } from './types.js';

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name} (see .env.example)`);
  return v;
}

const nodeEnv = process.env.NODE_ENV ?? 'development';
// BYPASS is only honored outside production — never weakens prod.
const bypassApple = process.env.BYPASS_APPLE_VERIFY === 'true' && nodeEnv !== 'production';
const appleClientId = process.env.APPLE_CLIENT_ID || undefined;
const adminApiKey = process.env.ADMIN_API_KEY || undefined;

const supabase = createSupabaseClient(
  requireEnv('SUPABASE_URL'),
  requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
);

const deps: AppDeps = {
  repo: createSupabaseRepo(supabase),
  jwtSecret: requireEnv('JWT_SECRET'),
  env: { nodeEnv, bypassApple, appleClientId, adminApiKey },
  verifyApple: (identityToken) =>
    verifyAppleIdentityToken(identityToken, { bypass: bypassApple, nodeEnv, appleClientId }),
  openai: createOpenAIProxy(requireEnv('OPENAI_API_KEY')),
  now: () => new Date(),
};

const app = createApp(deps);
const port = Number(process.env.PORT ?? 3000);

serve({ fetch: app.fetch, port }, (info) => {
  console.log(`Sous backend listening on :${info.port} (env: ${nodeEnv}, appleBypass: ${bypassApple})`);
});
