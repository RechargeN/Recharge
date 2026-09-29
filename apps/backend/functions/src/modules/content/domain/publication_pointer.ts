import type {
  ModerationHold,
  OwnerHold,
  PublicationPointerV1,
  PublicationVisibility,
} from '../../../contracts/content_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';
import { ContentDomainRefusal } from './failures.js';

export type PublicationPointer = DeepReadonly<PublicationPointerV1>;

/** Pointer revision that a not-yet-published content id is treated as having. */
export const absentPointerRevision = 0;

/**
 * Effective visibility. A moderation hold always wins over an owner hold, so a
 * restricted item stays restricted even if its owner also withdrew it.
 */
export function deriveVisibility(
  ownerHold: OwnerHold | null,
  moderationHold: ModerationHold | null,
): PublicationVisibility {
  if (moderationHold !== null) return moderationHold.kind;
  return ownerHold ?? 'visible';
}

export function isPubliclyVisible(pointer: PublicationPointer | null): boolean {
  return (
    pointer !== null &&
    pointer.visibility === 'visible' &&
    pointer.currentPublishedRevisionId !== null
  );
}

function next(
  pointer: PublicationPointer,
  change: {
    readonly currentPublishedRevisionId?: EntityId | null;
    readonly previousPublishedRevisionId?: EntityId | null;
    readonly ownerHold: OwnerHold | null;
    readonly moderationHold: ModerationHold | null;
  },
  nowUtc: UtcInstant,
): PublicationPointer {
  return deepFreeze({
    schemaVersion: 1,
    contentId: pointer.contentId,
    currentPublishedRevisionId:
      change.currentPublishedRevisionId === undefined
        ? pointer.currentPublishedRevisionId
        : change.currentPublishedRevisionId,
    previousPublishedRevisionId:
      change.previousPublishedRevisionId === undefined
        ? pointer.previousPublishedRevisionId
        : change.previousPublishedRevisionId,
    visibility: deriveVisibility(change.ownerHold, change.moderationHold),
    ownerHold: change.ownerHold,
    moderationHold: change.moderationHold === null ? null : { ...change.moderationHold },
    revision: pointer.revision + 1,
    updatedAtUtc: nowUtc,
  } satisfies PublicationPointerV1);
}

function assertExpected(pointer: PublicationPointer | null, expectedPointerRevision: number): void {
  if ((pointer?.revision ?? absentPointerRevision) !== expectedPointerRevision)
    throw new ContentDomainRefusal('revision_conflict');
}

/**
 * Point at a new immutable revision. Only the caller's observed pointer
 * revision is accepted, and a moderation hold can never be bypassed by
 * publishing: only its own decision chain lifts it. An owner hold is lifted by
 * the owner activating a revision.
 */
export function activateRevision(
  current: PublicationPointer | null,
  expectedPointerRevision: number,
  contentId: EntityId,
  publishedRevisionId: EntityId,
  nowUtc: UtcInstant,
): PublicationPointer {
  assertExpected(current, expectedPointerRevision);
  if (current === null)
    return deepFreeze({
      schemaVersion: 1,
      contentId,
      currentPublishedRevisionId: publishedRevisionId,
      previousPublishedRevisionId: null,
      visibility: 'visible',
      ownerHold: null,
      moderationHold: null,
      revision: absentPointerRevision + 1,
      updatedAtUtc: nowUtc,
    } satisfies PublicationPointerV1);
  if (current.moderationHold !== null) throw new ContentDomainRefusal('publication_restricted');
  return next(
    current,
    {
      currentPublishedRevisionId: publishedRevisionId,
      // Re-selecting the current revision (lifting an owner hold) keeps the
      // existing history; it never makes a revision its own predecessor.
      previousPublishedRevisionId:
        current.currentPublishedRevisionId === publishedRevisionId
          ? current.previousPublishedRevisionId
          : current.currentPublishedRevisionId,
      ownerHold: null,
      moderationHold: null,
    },
    nowUtc,
  );
}

/** Owner withdrawal or archival of the currently public revision. */
export function withdrawByOwner(
  current: PublicationPointer | null,
  expectedPointerRevision: number,
  mode: 'withdraw' | 'archive',
  nowUtc: UtcInstant,
): PublicationPointer {
  if (current === null) throw new ContentDomainRefusal('not_found');
  assertExpected(current, expectedPointerRevision);
  // Already held back by the owner: nothing left to withdraw.
  if (current.ownerHold !== null) throw new ContentDomainRefusal('revision_conflict');
  return next(
    current,
    {
      ownerHold: mode === 'archive' ? 'archived' : 'withdrawn',
      moderationHold: current.moderationHold,
    },
    nowUtc,
  );
}

const severity: Readonly<Record<ModerationHold['kind'], number>> = {
  restricted: 1,
  withdrawn: 2,
};

/**
 * Apply a moderation `restrict`/`withdraw` to the exact revision the decision
 * saw. A newer decision replaces an older one, but a decision can never
 * weaken a stronger active hold.
 */
export function applyModerationHold(
  current: PublicationPointer | null,
  targetPublishedRevisionId: EntityId | undefined,
  kind: ModerationHold['kind'],
  decisionId: string,
  nowUtc: UtcInstant,
): PublicationPointer {
  if (current === null || current.currentPublishedRevisionId === null)
    throw new ContentDomainRefusal('not_found');
  if (
    targetPublishedRevisionId !== undefined &&
    targetPublishedRevisionId !== current.currentPublishedRevisionId
  )
    throw new ContentDomainRefusal('moderation_decision_stale');
  const active = current.moderationHold;
  if (active !== null && severity[kind] < severity[active.kind])
    throw new ContentDomainRefusal('moderation_decision_stale');
  return next(
    current,
    { ownerHold: current.ownerHold, moderationHold: { kind, decisionId } },
    nowUtc,
  );
}

/**
 * Lift exactly the moderation hold the decision names. If another decision has
 * since replaced it, this restore is stale and creates nothing. The owner's own
 * hold, if any, is untouched.
 */
export function restoreModerationHold(
  current: PublicationPointer | null,
  restoresDecisionId: string,
  nowUtc: UtcInstant,
): PublicationPointer {
  if (current === null) throw new ContentDomainRefusal('not_found');
  if (current.moderationHold?.decisionId !== restoresDecisionId)
    throw new ContentDomainRefusal('moderation_decision_stale');
  return next(current, { ownerHold: current.ownerHold, moderationHold: null }, nowUtc);
}
