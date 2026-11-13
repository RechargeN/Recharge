import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import type {
  ScenarioRevisionPort,
  ScenarioRevisionStatus,
} from '../content/application/ports/scenario_revision_port.js';
import {
  scenarioStopRefs,
  type ScenarioStopLookup,
  type ScenarioStopObjectType,
} from '../content/domain/type_rules/scenario_rules.js';

/**
 * SCN-PUB-01 Planning side: immutable distribution revisions, the unlisted
 * share token (SP-03/SP-04) and the verified share restriction. Records:
 *
 * - `scenarioRevisions/{revisionId}` — immutable `{scenarioId, ownerId,
 *   purpose, sourceRevision, contentHash, distribution, createdAtUtc}`;
 * - `scenarioShares/{sha256(token)}` — `{scenarioId, ownerId, revisionId,
 *   status, expiresAtUtc, restriction, createdAtUtc}`; the token itself is
 *   never stored, so the document id is its hash.
 */
export const scenarioPublicationCollections = Object.freeze({
  revisions: 'scenarioRevisions',
  shares: 'scenarioShares',
});

/** SP-04 TEST-ONLY Emulator values: 30 days by default, at most 90. */
export const shareTtlDays = Object.freeze({ default: 30, max: 90 });

export interface ScenarioRevisionRecord {
  readonly scenarioId: string;
  readonly ownerId: string;
  readonly purpose: 'public' | 'unlisted';
  readonly sourceRevision: number;
  readonly contentHash: string;
  readonly distribution: Record<string, unknown>;
  readonly createdAtUtc: string;
}

export interface ScenarioShareRecord {
  readonly scenarioId: string;
  readonly ownerId: string;
  readonly revisionId: string;
  readonly status: 'active' | 'revoked' | 'rotated';
  readonly expiresAtUtc: string;
  readonly restriction: { readonly decisionId: string } | null;
  readonly createdAtUtc: string;
}

/** 256 bits from the CSPRNG, URL-safe; never derived from ids or time. */
export function newShareToken(): string {
  return randomBytes(32).toString('base64url');
}

export function isShareToken(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value);
}

export function shareTokenHash(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

/** Constant-time comparison of the stored hash with the presented token's. */
export function shareHashMatches(stored: string, token: string): boolean {
  const a = Buffer.from(stored, 'hex');
  const b = Buffer.from(shareTokenHash(token), 'hex');
  return a.length === b.length && timingSafeEqual(a, b);
}

/** What Planning needs from the Catalog-owned exact-id evaluator. */
export interface ScenarioStopsPort {
  statusOf(input: {
    readonly objectType: ScenarioStopObjectType;
    readonly objectId: string;
    readonly marketId: string;
  }): Promise<string>;
}

/**
 * Resolves every catalog stop of a mapped draft once, before any Planning
 * transaction is opened; without a port every stop is unresolved (fail closed).
 */
export async function scenarioStopLookup(
  draft: unknown,
  port: ScenarioStopsPort | undefined,
): Promise<ScenarioStopLookup> {
  const scenario = (draft as { scenario?: { items?: unknown[] } } | null)?.scenario;
  const refs = scenarioStopRefs({
    items: (scenario?.items ?? []).map((item) => {
      const source = (item as { source?: Record<string, unknown> }).source;
      return source?.type === 'catalog'
        ? { stop: { type: 'catalog', objectType: source.objectType, objectId: source.objectId } }
        : {};
    }),
  });
  const statuses = new Map<string, 'ready' | 'unavailable' | undefined>();
  for (const ref of refs) {
    let status: string = 'unavailable_answer';
    try {
      status = (await port?.statusOf({ ...ref, marketId: 'LV' })) ?? 'unavailable_answer';
    } catch {
      status = 'unavailable_answer';
    }
    statuses.set(
      `${ref.objectType}:${ref.objectId}`,
      status === 'ready' ? 'ready' : status === 'unavailable_answer' ? undefined : 'unavailable',
    );
  }
  return (objectType, objectId) => statuses.get(`${objectType}:${objectId}`);
}

/** SP-06: Planning's answer to Content about one pinned public revision. */
export class FirestoreScenarioRevisionReader implements ScenarioRevisionPort {
  constructor(private readonly db: Firestore) {}

  async verify(input: {
    readonly scenarioId: string;
    readonly scenarioRevisionId: string;
    readonly contentHash: string;
    readonly ownerUserId: string;
  }): Promise<ScenarioRevisionStatus> {
    try {
      const revision = (
        await this.db
          .collection(scenarioPublicationCollections.revisions)
          .doc(input.scenarioRevisionId)
          .get()
      ).data() as ScenarioRevisionRecord | undefined;
      if (revision === undefined) return 'unknown';
      if (
        revision.scenarioId !== input.scenarioId ||
        revision.ownerId !== input.ownerUserId ||
        revision.purpose !== 'public' ||
        revision.contentHash !== input.contentHash
      )
        return 'forbidden';
      const plan = (await this.db.collection('scenarios').doc(input.scenarioId).get()).data();
      return plan?.status === 'active' && plan.ownerId === input.ownerUserId ? 'ok' : 'stale';
    } catch {
      return 'unavailable';
    }
  }
}

/** Verifies a staff decision for one share (the moderation module answers). */
export interface ShareRestrictionAuthority {
  verifyShareRestriction(input: {
    readonly shareId: string;
    readonly decisionRef: string;
    readonly restricted: boolean;
  }): Promise<{ readonly verified: boolean; readonly restoresDecisionRef?: string }>;
}

export type ShareRestrictionOutcome =
  | { readonly kind: 'applied'; readonly outcome: 'applied' | 'already_applied' }
  | { readonly kind: 'refused'; readonly code: string };

/**
 * The one write path of a share restriction: only a verified staff decision
 * restricts a share, and a restore lifts exactly the restriction it names.
 */
export async function applyShareRestriction(
  db: Firestore,
  authority: ShareRestrictionAuthority,
  input: { readonly decisionId: string; readonly shareId: string; readonly restricted: boolean },
): Promise<ShareRestrictionOutcome> {
  const verdict = await authority.verifyShareRestriction({
    shareId: input.shareId,
    decisionRef: input.decisionId,
    restricted: input.restricted,
  });
  if (!verdict.verified) return { kind: 'refused', code: 'capability_denied' };
  const ref = db.collection(scenarioPublicationCollections.shares).doc(input.shareId);
  return db.runTransaction(async (tx) => {
    const share = (await tx.get(ref)).data() as ScenarioShareRecord | undefined;
    if (share === undefined) return { kind: 'refused', code: 'target_not_found' };
    if (input.restricted) {
      if (share.restriction?.decisionId === input.decisionId)
        return { kind: 'applied', outcome: 'already_applied' };
      tx.update(ref, { restriction: { decisionId: input.decisionId } });
      return { kind: 'applied', outcome: 'applied' };
    }
    if (share.restriction === null) return { kind: 'applied', outcome: 'already_applied' };
    if (share.restriction.decisionId !== verdict.restoresDecisionRef)
      return { kind: 'refused', code: 'moderation_decision_stale' };
    tx.update(ref, { restriction: null });
    return { kind: 'applied', outcome: 'applied' };
  });
}
