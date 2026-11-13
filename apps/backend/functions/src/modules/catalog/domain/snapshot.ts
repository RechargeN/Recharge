import { createHash, createHmac, timingSafeEqual } from 'node:crypto';

import { catalogPolicyRevisions, catalogTestOnlyConfig } from './catalog_config.js';
import type { SortKey } from './evaluation.js';

/**
 * TEST-ONLY signing key of the local Emulator stand. Tokens and cursors are
 * opaque and tamper-evident here; this is not a production secret.
 */
const testOnlySnapshotKey = 'test-only-emulator-catalog-snapshot-key-v1';

/** One snapshot shared by Feed, Map, Search and Details for one applied query. */
export interface SnapshotClaims {
  readonly v: 1;
  readonly projectionFamilies?: string;
  readonly queryFingerprint: string;
  readonly projectionSetId: string;
  readonly projectionSetRevision: number;
  readonly visibilityPolicyRevision: string;
  readonly referenceDatasetRevision: string;
  readonly rankingPolicyRevision: string;
  readonly availabilityCompositionRevision: string;
  /** Server time every page of this snapshot evaluates against. */
  readonly nowUtc: string;
  readonly issuedAtUtc: string;
  readonly expiresAtUtc: string;
}

export interface CursorClaims {
  readonly v: 1;
  /** Binds the cursor to exactly one snapshot token. */
  readonly tokenDigest: string;
  readonly lastKey: SortKey;
}

function sign(payload: string): string {
  return createHmac('sha256', testOnlySnapshotKey).update(payload, 'utf8').digest('base64url');
}

function encode(claims: object): string {
  const payload = Buffer.from(JSON.stringify(claims), 'utf8').toString('base64url');
  return `${payload}.${sign(payload)}`;
}

function decode(value: unknown): unknown {
  if (typeof value !== 'string' || value.length > 4096) return null;
  const [payload, tag, extra] = value.split('.');
  if (payload === undefined || tag === undefined || extra !== undefined) return null;
  const expected = Buffer.from(sign(payload), 'utf8');
  const actual = Buffer.from(tag, 'utf8');
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) return null;
  try {
    return JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as unknown;
  } catch {
    return null;
  }
}

export function issueSnapshot(input: {
  readonly queryFingerprint: string;
  readonly projectionSetId: string;
  readonly projectionSetRevision: number;
  readonly referenceDatasetRevision: string;
  readonly nowMs: number;
}): { readonly token: string; readonly claims: SnapshotClaims } {
  const now = new Date(input.nowMs).toISOString();
  const claims: SnapshotClaims = {
    v: 1,
    projectionFamilies: catalogPolicyRevisions.projectionFamilies,
    queryFingerprint: input.queryFingerprint,
    projectionSetId: input.projectionSetId,
    projectionSetRevision: input.projectionSetRevision,
    visibilityPolicyRevision: catalogPolicyRevisions.visibility,
    referenceDatasetRevision: input.referenceDatasetRevision,
    rankingPolicyRevision: catalogPolicyRevisions.ranking,
    availabilityCompositionRevision: catalogPolicyRevisions.availabilityComposition,
    nowUtc: now,
    issuedAtUtc: now,
    expiresAtUtc: new Date(
      input.nowMs + catalogTestOnlyConfig.snapshotTtlSeconds * 1000,
    ).toISOString(),
  };
  return { token: encode(claims), claims };
}

export type SnapshotCheck =
  | { readonly ok: true; readonly claims: SnapshotClaims }
  | {
      readonly ok: false;
      readonly code:
        | 'snapshot_invalid'
        | 'snapshot_expired'
        | 'snapshot_query_mismatch'
        | 'snapshot_incompatible';
    };

/**
 * A token is usable only for the same applied query, while it lives, and only
 * with the policy revisions this build serves; anything else is typed, never
 * quietly combined with another snapshot.
 */
export function verifySnapshot(
  token: unknown,
  queryFingerprint: string,
  nowMs: number,
): SnapshotCheck {
  const claims = decode(token) as SnapshotClaims | null;
  if (
    claims === null ||
    claims.v !== 1 ||
    (claims.projectionFamilies !== undefined &&
      claims.projectionFamilies !== catalogPolicyRevisions.projectionFamilies)
  )
    return { ok: false, code: 'snapshot_invalid' };
  if (Date.parse(claims.expiresAtUtc) <= nowMs) return { ok: false, code: 'snapshot_expired' };
  if (claims.queryFingerprint !== queryFingerprint)
    return { ok: false, code: 'snapshot_query_mismatch' };
  if (
    claims.visibilityPolicyRevision !== catalogPolicyRevisions.visibility ||
    claims.rankingPolicyRevision !== catalogPolicyRevisions.ranking ||
    claims.availabilityCompositionRevision !== catalogPolicyRevisions.availabilityComposition
  )
    return { ok: false, code: 'snapshot_incompatible' };
  return { ok: true, claims };
}

export function tokenDigest(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

export function issueCursor(token: string, lastKey: SortKey): string {
  return encode({ v: 1, tokenDigest: tokenDigest(token), lastKey } satisfies CursorClaims);
}

export type CursorCheck =
  | { readonly ok: true; readonly lastKey: SortKey }
  | { readonly ok: false; readonly code: 'cursor_invalid' | 'cursor_snapshot_mismatch' };

/** A cursor continues exactly the snapshot it was issued for. */
export function verifyCursor(cursor: unknown, token: string): CursorCheck {
  const claims = decode(cursor) as CursorClaims | null;
  if (
    claims === null ||
    claims.v !== 1 ||
    !Array.isArray(claims.lastKey) ||
    claims.lastKey.length !== 4 ||
    typeof claims.lastKey[3] !== 'string' ||
    ![0, 1, 2].every((index) => typeof claims.lastKey[index] === 'number')
  )
    return { ok: false, code: 'cursor_invalid' };
  if (claims.tokenDigest !== tokenDigest(token))
    return { ok: false, code: 'cursor_snapshot_mismatch' };
  return { ok: true, lastKey: claims.lastKey };
}
