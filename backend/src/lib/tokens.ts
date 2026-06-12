// Sous session tokens.
//
// A Sous session token is a signed JWT (HS256) with a 30-day expiry. The token
// is also persisted in the `sessions` table so it can be revoked server-side
// (sign-out, account deletion). Verification therefore has two halves:
//   1. Cryptographic: the JWT signature + expiry (this file).
//   2. Stateful: the `sessions` row exists, is not revoked, not expired (auth
//      middleware, which calls verifySessionToken first then checks the DB).

import { SignJWT, jwtVerify, type JWTPayload } from 'jose';

const THIRTY_DAYS_SECONDS = 30 * 24 * 60 * 60;

export interface SousTokenClaims {
  /** Sous user id (uuid). */
  userId: string;
  /** Sessions-table row id this token corresponds to. */
  sessionId: string;
}

function secretKey(jwtSecret: string): Uint8Array {
  return new TextEncoder().encode(jwtSecret);
}

/**
 * Sign a new Sous session token. `expiresAt` is returned so the caller can
 * persist the matching `sessions.expires_at`.
 */
export async function signSessionToken(
  claims: SousTokenClaims,
  jwtSecret: string,
  now: Date = new Date(),
): Promise<{ token: string; expiresAt: Date }> {
  const iat = Math.floor(now.getTime() / 1000);
  const exp = iat + THIRTY_DAYS_SECONDS;

  const token = await new SignJWT({ sid: claims.sessionId })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(claims.userId)
    .setIssuedAt(iat)
    .setExpirationTime(exp)
    .setIssuer('sous')
    .sign(secretKey(jwtSecret));

  return { token, expiresAt: new Date(exp * 1000) };
}

/**
 * Verify the cryptographic half of a session token. Throws if the signature is
 * invalid or the token is expired. Returns the decoded claims on success.
 */
export async function verifySessionToken(
  token: string,
  jwtSecret: string,
): Promise<SousTokenClaims> {
  const { payload } = await jwtVerify(token, secretKey(jwtSecret), {
    issuer: 'sous',
  });
  return claimsFromPayload(payload);
}

function claimsFromPayload(payload: JWTPayload): SousTokenClaims {
  const userId = payload.sub;
  const sessionId = typeof payload.sid === 'string' ? payload.sid : undefined;
  if (!userId || !sessionId) {
    throw new Error('Malformed session token: missing sub or sid');
  }
  return { userId, sessionId };
}
