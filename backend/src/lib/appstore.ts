// Apple App Store verification boundary (Project 4: Billing).
//
// StoreKit 2 hands the client a *signed JWS* for every transaction
// (`Transaction.jwsRepresentation`), and App Store Server Notifications v2 POST a
// `signedPayload` JWS. Both are signed by Apple's PKI (ES256, with the signing
// certificate chain in the JWS `x5c` header). Verifying them is therefore a
// purely cryptographic operation — there is no "production vs sandbox endpoint"
// to call as there was with the deprecated /verifyReceipt API. The `environment`
// field inside the payload tells us whether the transaction came from Sandbox or
// Production, so sandbox transactions verify by exactly the same path (this is the
// "fall back to sandbox" behaviour the plan asks for, handled for free).
//
// SECURITY MODEL
//   1. The JWS `alg` MUST be ES256. We never honour `none`/HS* (alg-confusion).
//   2. The `x5c` certificate chain is validated end to end:
//        leaf  ← signed by → intermediate ← signed by → root (self-signed)
//      Every link's signature is verified, validity windows are checked, and the
//      root is PINNED to Apple Root CA - G3 by SHA-256 fingerprint. A forged chain
//      terminating in an attacker root is rejected (fail-closed).
//   3. Only after the chain is trusted do we verify the JWS body signature with
//      the leaf certificate's public key.
//
// The verifier is injected via AppDeps so tests can supply a fake (no Apple keys,
// no network). Production wires `createAppStoreVerifier`.

import { X509Certificate } from 'node:crypto';
import { compactVerify, decodeProtectedHeader } from 'jose';

// Apple Root CA - G3 SHA-256 fingerprint, formatted exactly as Node's
// X509Certificate.fingerprint256 emits it (uppercase, colon-separated).
//
// ⚠️ OPERATOR: confirm this against Apple's published value
// (https://www.apple.com/certificateauthority/ — "Apple Root CA - G3") before
// going live. If it is wrong, verification fails CLOSED (purchases are rejected,
// never spoofed). Override without a code change via APPLE_ROOT_CA_FINGERPRINT.
export const APPLE_ROOT_CA_G3_FINGERPRINT_256 =
  '63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79';

export class AppStoreVerifyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AppStoreVerifyError';
  }
}

/** A verified, decoded StoreKit transaction (JWSTransactionDecodedPayload). */
export interface VerifiedTransaction {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  /** ISO 8601. */
  purchaseDate: string;
  /** ISO 8601; null for non-renewing products. */
  expiresDate: string | null;
  /** ISO 8601; set when the transaction was refunded/revoked. */
  revocationDate: string | null;
  environment: string;
}

/** A verified App Store Server Notification v2 payload. */
export interface DecodedNotification {
  notificationType: string;
  subtype: string | null;
  notificationUUID: string | null;
  bundleId: string | null;
  environment: string | null;
  /** The (separately verified) transaction the notification carries, if any. */
  transaction: VerifiedTransaction | null;
}

export interface AppStoreVerifier {
  /** Verify a StoreKit 2 signed transaction JWS → decoded transaction. Throws on failure. */
  verifyTransaction(signedTransaction: string): Promise<VerifiedTransaction>;
  /** Verify an ASSN v2 signedPayload JWS → decoded notification. Throws on failure. */
  verifyNotification(signedPayload: string): Promise<DecodedNotification>;
}

export interface AppStoreVerifierOptions {
  /** Pin override (uppercase colon-separated SHA-256). Defaults to Apple Root CA - G3. */
  rootFingerprint256?: string;
  /** When set, transactions whose bundleId differs are rejected. */
  expectedBundleId?: string;
  /** Injectable clock for certificate validity checks. */
  now?: () => Date;
}

function withinValidity(cert: X509Certificate, now: Date): boolean {
  return cert.validFromDate <= now && now <= cert.validToDate;
}

/**
 * Validate an x5c chain: every certificate is signed by the next, validity
 * windows hold, and the final certificate is the pinned, self-signed Apple root.
 */
function verifyChain(chain: X509Certificate[], rootFp: string, now: Date): void {
  if (chain.length < 2) throw new AppStoreVerifyError('certificate chain too short');

  for (let i = 0; i < chain.length - 1; i++) {
    const cert = chain[i]!;
    const issuer = chain[i + 1]!;
    if (!withinValidity(cert, now)) {
      throw new AppStoreVerifyError(`certificate ${i} outside its validity window`);
    }
    if (!cert.checkIssued(issuer)) {
      throw new AppStoreVerifyError(`certificate ${i} not issued by the next in chain`);
    }
    if (!cert.verify(issuer.publicKey)) {
      throw new AppStoreVerifyError(`certificate ${i} signature does not verify`);
    }
  }

  const root = chain[chain.length - 1]!;
  if (!withinValidity(root, now)) {
    throw new AppStoreVerifyError('root certificate outside its validity window');
  }
  // Root must be self-signed and match the pinned Apple root fingerprint.
  if (!root.verify(root.publicKey)) {
    throw new AppStoreVerifyError('root certificate is not self-signed');
  }
  if (root.fingerprint256.toUpperCase() !== rootFp) {
    throw new AppStoreVerifyError('certificate chain does not terminate in the trusted Apple root');
  }
}

function msToIso(value: unknown): string | null {
  return typeof value === 'number' && Number.isFinite(value)
    ? new Date(value).toISOString()
    : null;
}

function toVerifiedTransaction(p: Record<string, unknown>): VerifiedTransaction {
  return {
    transactionId: typeof p.transactionId === 'string' ? p.transactionId : '',
    originalTransactionId:
      typeof p.originalTransactionId === 'string' ? p.originalTransactionId : '',
    bundleId: typeof p.bundleId === 'string' ? p.bundleId : '',
    productId: typeof p.productId === 'string' ? p.productId : '',
    purchaseDate: msToIso(p.purchaseDate) ?? new Date(0).toISOString(),
    expiresDate: msToIso(p.expiresDate),
    revocationDate: msToIso(p.revocationDate),
    environment: typeof p.environment === 'string' ? p.environment : 'Production',
  };
}

export function createAppStoreVerifier(
  options: AppStoreVerifierOptions = {},
): AppStoreVerifier {
  const rootFp = (options.rootFingerprint256 ?? APPLE_ROOT_CA_G3_FINGERPRINT_256).toUpperCase();
  const now = options.now ?? (() => new Date());

  async function verifyJws(jws: string): Promise<Record<string, unknown>> {
    let header: { alg?: string; x5c?: string[] };
    try {
      header = decodeProtectedHeader(jws) as { alg?: string; x5c?: string[] };
    } catch {
      throw new AppStoreVerifyError('malformed JWS header');
    }
    if (header.alg !== 'ES256') {
      throw new AppStoreVerifyError(`unexpected JWS alg: ${header.alg ?? 'none'}`);
    }
    const x5c = header.x5c;
    if (!Array.isArray(x5c) || x5c.length < 2) {
      throw new AppStoreVerifyError('JWS missing x5c certificate chain');
    }

    let chain: X509Certificate[];
    try {
      chain = x5c.map((b64) => new X509Certificate(Buffer.from(b64, 'base64')));
    } catch {
      throw new AppStoreVerifyError('JWS x5c contains an invalid certificate');
    }

    verifyChain(chain, rootFp, now());

    let payload: Uint8Array;
    try {
      ({ payload } = await compactVerify(jws, chain[0]!.publicKey));
    } catch {
      throw new AppStoreVerifyError('JWS body signature does not verify');
    }

    try {
      return JSON.parse(new TextDecoder().decode(payload)) as Record<string, unknown>;
    } catch {
      throw new AppStoreVerifyError('JWS payload is not valid JSON');
    }
  }

  async function verifyTransaction(signedTransaction: string): Promise<VerifiedTransaction> {
    const payload = await verifyJws(signedTransaction);
    const txn = toVerifiedTransaction(payload);
    if (options.expectedBundleId && txn.bundleId && txn.bundleId !== options.expectedBundleId) {
      throw new AppStoreVerifyError('transaction bundle id does not match this app');
    }
    return txn;
  }

  async function verifyNotification(signedPayload: string): Promise<DecodedNotification> {
    const payload = await verifyJws(signedPayload);
    const data = (typeof payload.data === 'object' && payload.data !== null
      ? (payload.data as Record<string, unknown>)
      : {}) as Record<string, unknown>;

    let transaction: VerifiedTransaction | null = null;
    if (typeof data.signedTransactionInfo === 'string') {
      // The embedded transaction is itself a JWS — verify it independently.
      transaction = await verifyTransaction(data.signedTransactionInfo);
    }

    return {
      notificationType: typeof payload.notificationType === 'string' ? payload.notificationType : '',
      subtype: typeof payload.subtype === 'string' ? payload.subtype : null,
      notificationUUID:
        typeof payload.notificationUUID === 'string' ? payload.notificationUUID : null,
      bundleId: typeof data.bundleId === 'string' ? data.bundleId : null,
      environment: typeof data.environment === 'string' ? data.environment : null,
      transaction,
    };
  }

  return { verifyTransaction, verifyNotification };
}
