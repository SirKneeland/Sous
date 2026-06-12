// Sign in with Apple — identity token verification.
//
// The iOS client performs Sign in with Apple and sends us the resulting
// `identityToken` (a JWT signed by Apple). We verify it against Apple's public
// keys and extract the `sub` claim, which is the stable, canonical Apple user id
// we key our accounts on.
//
// DEV BYPASS: when BYPASS_APPLE_VERIFY=true AND NODE_ENV !== 'production', this
// module skips network verification and trusts the provided token string as the
// `sub` (or a fixed default). This lets the operator exercise /auth/apple in
// Postman without a real device token. The bypass is hard-disabled in production.

import { createRemoteJWKSet, jwtVerify } from 'jose';

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';

// createRemoteJWKSet caches keys internally and refreshes as needed.
const appleJWKS = createRemoteJWKSet(new URL(APPLE_KEYS_URL));

export interface AppleVerifyOptions {
  bypass: boolean;
  nodeEnv: string;
  /** The app's bundle id / Services id; checked as the token audience when set. */
  appleClientId?: string;
}

export interface AppleIdentity {
  /** Canonical Apple subject id. */
  sub: string;
  /** Email if Apple included one (first sign-in, or if not hidden). */
  email?: string;
}

export class AppleVerificationError extends Error {}

/**
 * Verify an Apple identity token and return its identity claims.
 * Throws AppleVerificationError on any failure.
 */
export async function verifyAppleIdentityToken(
  identityToken: string,
  opts: AppleVerifyOptions,
): Promise<AppleIdentity> {
  const bypassAllowed = opts.bypass && opts.nodeEnv !== 'production';
  if (bypassAllowed) {
    // Treat the supplied token as the test `sub` so multiple fake users can be
    // exercised by varying the token. Fall back to a fixed dev sub.
    const sub = identityToken?.trim() || 'test-apple-sub-dev';
    return { sub, email: `${sub}@example.test` };
  }

  if (!identityToken) {
    throw new AppleVerificationError('Missing identityToken');
  }

  try {
    const { payload } = await jwtVerify(identityToken, appleJWKS, {
      issuer: APPLE_ISSUER,
      audience: opts.appleClientId || undefined,
    });
    if (!payload.sub) {
      throw new AppleVerificationError('Apple token missing sub claim');
    }
    return {
      sub: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
    };
  } catch (err) {
    if (err instanceof AppleVerificationError) throw err;
    throw new AppleVerificationError(
      `Apple identity token verification failed: ${(err as Error).message}`,
    );
  }
}
