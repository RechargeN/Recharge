import { parseEntityId, type EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';

/**
 * L1 legal hold (BCK-04 §19.2, BCK04-SEC-DEC-01 item 10): a server-side record
 * with an exact scope, a revision, a review date and an audit trail. The basis
 * is an opaque reference kept for the hold authority only: DSR answers, task
 * evidence and progress never carry it. A hold never counts as a deletion.
 */
export interface PrivacyLegalHoldScope {
  /** A privacy domain or `*` for every domain of the subject. */
  readonly domainId: string;
  /** A collection of that domain or `*`. */
  readonly collection: string;
  /** One document, or `null` for every record of the subject in the scope. */
  readonly recordId: string | null;
}

export interface PrivacyLegalHold {
  readonly schemaVersion: 1;
  readonly holdId: EntityId;
  readonly subjectId: EntityId;
  readonly scope: PrivacyLegalHoldScope;
  readonly status: 'active' | 'released';
  readonly revision: number;
  readonly basisRef: string;
  readonly reviewAtUtc: UtcInstant;
  readonly placedBy: string;
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
}

const scopePart = /^(?:\*|[a-z][a-z0-9._-]{0,63}|[A-Za-z][A-Za-z0-9]{0,95})$/;

function parseScope(scope: PrivacyLegalHoldScope): PrivacyLegalHoldScope {
  if (
    !scopePart.test(scope.domainId) ||
    !scopePart.test(scope.collection) ||
    (scope.recordId !== null && !/^[^/]{1,1500}$/.test(scope.recordId)) ||
    (scope.domainId === '*' && (scope.collection !== '*' || scope.recordId !== null)) ||
    (scope.collection === '*' && scope.recordId !== null)
  )
    throw new TypeError('privacy_hold_scope_invalid');
  return { domainId: scope.domainId, collection: scope.collection, recordId: scope.recordId };
}

function parseBasisRef(value: string): string {
  if (!/^[A-Za-z0-9:._-]{1,128}$/.test(value)) throw new TypeError('privacy_hold_basis_invalid');
  return value;
}

function parseReviewAt(reviewAtUtc: string, nowUtc: UtcInstant): UtcInstant {
  const review = parseUtcInstant(reviewAtUtc);
  if (Date.parse(review) <= Date.parse(nowUtc)) throw new TypeError('privacy_hold_review_invalid');
  return review;
}

export function placePrivacyLegalHold(input: {
  readonly holdId: string;
  readonly subjectId: string;
  readonly scope: PrivacyLegalHoldScope;
  readonly basisRef: string;
  readonly reviewAtUtc: string;
  readonly placedBy: string;
  readonly nowUtc: string;
}): DeepReadonly<PrivacyLegalHold> {
  const nowUtc = parseUtcInstant(input.nowUtc);
  return deepFreeze({
    schemaVersion: 1,
    holdId: parseEntityId(input.holdId),
    subjectId: parseEntityId(input.subjectId),
    scope: parseScope(input.scope),
    status: 'active',
    revision: 1,
    basisRef: parseBasisRef(input.basisRef),
    reviewAtUtc: parseReviewAt(input.reviewAtUtc, nowUtc),
    placedBy: input.placedBy,
    createdAtUtc: nowUtc,
    updatedAtUtc: nowUtc,
  });
}

/** Scope or review change by the authority; the subject never widens a hold. */
export function changePrivacyLegalHold(input: {
  readonly hold: PrivacyLegalHold;
  readonly scope?: PrivacyLegalHoldScope;
  readonly reviewAtUtc?: string;
  readonly nowUtc: string;
}): DeepReadonly<PrivacyLegalHold> {
  if (input.hold.status !== 'active') throw new TypeError('privacy_hold_not_active');
  const nowUtc = parseUtcInstant(input.nowUtc);
  return deepFreeze({
    ...input.hold,
    scope: input.scope === undefined ? input.hold.scope : parseScope(input.scope),
    reviewAtUtc:
      input.reviewAtUtc === undefined
        ? input.hold.reviewAtUtc
        : parseReviewAt(input.reviewAtUtc, nowUtc),
    revision: input.hold.revision + 1,
    updatedAtUtc: nowUtc,
  });
}

export function releasePrivacyLegalHold(input: {
  readonly hold: PrivacyLegalHold;
  readonly nowUtc: string;
}): DeepReadonly<PrivacyLegalHold> {
  if (input.hold.status !== 'active') throw new TypeError('privacy_hold_not_active');
  return deepFreeze({
    ...input.hold,
    status: 'released',
    revision: input.hold.revision + 1,
    updatedAtUtc: parseUtcInstant(input.nowUtc),
  });
}

/** Whether an active hold protects this record of the subject. */
export function privacyHoldApplies(
  hold: Pick<PrivacyLegalHold, 'status' | 'scope'>,
  target: { readonly domainId: string; readonly collection: string; readonly recordId: string },
): boolean {
  return (
    hold.status === 'active' &&
    (hold.scope.domainId === '*' || hold.scope.domainId === target.domainId) &&
    (hold.scope.collection === '*' || hold.scope.collection === target.collection) &&
    (hold.scope.recordId === null || hold.scope.recordId === target.recordId)
  );
}
