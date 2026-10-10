import type {
  ContentEffectV1,
  MediaConfirmationV1,
  MediaSuppressionV1,
  ModerationHold,
  OwnerHold,
  PublicationPointerV1,
  PublicationVisibility,
} from '../../../contracts/content_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';
import { ContentDomainRefusal } from './failures.js';
import type { PublishedRevision } from './published_revision.js';

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

/** Confirmed epochs and suppressed media, stored only when non-empty (D2 §5.1). */
function mediaFields(
  confirmations: readonly MediaConfirmationV1[],
  suppression: readonly MediaSuppressionV1[],
): Pick<PublicationPointerV1, 'mediaConfirmations' | 'mediaSuppression'> {
  const byAsset = <T extends { readonly assetId: string }>(items: readonly T[]): T[] =>
    [...items].sort((left, right) => (left.assetId < right.assetId ? -1 : 1));
  return {
    ...(confirmations.length === 0
      ? {}
      : { mediaConfirmations: byAsset(confirmations).map((item) => ({ ...item })) }),
    ...(suppression.length === 0
      ? {}
      : { mediaSuppression: byAsset(suppression).map((item) => ({ ...item })) }),
  };
}

export function mediaConfirmationsOf(
  pointer: PublicationPointer | null,
): readonly MediaConfirmationV1[] {
  return pointer?.mediaConfirmations ?? [];
}

export function mediaSuppressionOf(
  pointer: PublicationPointer | null,
): readonly MediaSuppressionV1[] {
  return pointer?.mediaSuppression ?? [];
}

/** Ids of the media the pointer suppresses, sorted; empty when none. */
export function suppressedMediaIds(pointer: PublicationPointer | null): readonly EntityId[] {
  return mediaSuppressionOf(pointer).map((item) => item.assetId);
}

/**
 * The committed fact of a pointer change. Every fact carries the media the
 * pointer suppresses at that moment (omitted when none, so earlier facts keep
 * their hash): a consumer that replays facts never shows suppressed media again.
 */
export function contentEffect(
  revision: PublishedRevision,
  pointer: PublicationPointer,
  kind: ContentEffectV1['kind'],
  effectId: string,
  nowUtc: UtcInstant,
): ContentEffectV1 {
  const suppressed = suppressedMediaIds(pointer);
  return deepFreeze({
    schemaVersion: 1,
    effectId,
    kind,
    contentId: revision.contentId,
    publishedRevisionId: revision.publishedRevisionId,
    pointerRevision: pointer.revision,
    visibility: pointer.visibility,
    typeId: revision.typeId,
    publisherRef: { ...revision.publisherRef },
    marketId: revision.marketId,
    referenceRevisions: { ...revision.referenceRevisions },
    occurredAtUtc: nowUtc,
    ...(suppressed.length === 0 ? {} : { suppressedMediaIds: [...suppressed] }),
  });
}

/**
 * Whether an activation of the current revision would change what the pointer
 * confirms: some media is suppressed, or Media now reports another epoch than
 * the confirmed one (a restriction came and went, D2 §5.4).
 */
export function mediaNeedsConfirmation(
  pointer: PublicationPointer,
  evidence: readonly MediaConfirmationV1[],
): boolean {
  if (mediaSuppressionOf(pointer).length > 0) return true;
  const confirmed = mediaConfirmationsOf(pointer);
  if (confirmed.length !== evidence.length) return true;
  return evidence.some(
    (item) =>
      confirmed.find((stored) => stored.assetId === item.assetId)?.revocationEpoch !==
      item.revocationEpoch,
  );
}

function next(
  pointer: PublicationPointer,
  change: {
    readonly currentPublishedRevisionId?: EntityId | null;
    readonly previousPublishedRevisionId?: EntityId | null;
    readonly ownerHold: OwnerHold | null;
    readonly moderationHold: ModerationHold | null;
    /** Undefined keeps what the pointer confirms and suppresses. */
    readonly mediaConfirmations?: readonly MediaConfirmationV1[];
    readonly mediaSuppression?: readonly MediaSuppressionV1[];
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
    ...mediaFields(
      change.mediaConfirmations ?? mediaConfirmationsOf(pointer),
      change.mediaSuppression ?? mediaSuppressionOf(pointer),
    ),
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
 * the owner activating a revision. The activation confirms exactly the media
 * epochs of its evidence and clears every suppression (D2 §5.4).
 */
export function activateRevision(
  current: PublicationPointer | null,
  expectedPointerRevision: number,
  contentId: EntityId,
  publishedRevisionId: EntityId,
  nowUtc: UtcInstant,
  mediaConfirmations: readonly MediaConfirmationV1[] = [],
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
      ...mediaFields(mediaConfirmations, []),
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
      mediaConfirmations,
      mediaSuppression: [],
    },
    nowUtc,
  );
}

/** What Media reports about one attached asset now (structural; D2 §5.2). */
export interface AttachedMediaState {
  readonly assetId: string;
  readonly state: 'deliverable' | 'restricted' | 'held' | 'not_ready' | 'deleted' | 'absent';
  readonly revocationEpoch: number;
  readonly sourceGeneration?: string;
  readonly variantManifestRevision?: string;
}

/**
 * The suppressions the current revision needs, decided from Media's current
 * state, never from an event: a deleted or missing asset is `deleted`; a
 * restricted one, one without a confirmation, one whose epoch moved since the
 * confirmation (a restriction came, even if it went again) or whose generation
 * no longer matches the pin is `revoked`. A deletion hold alone changes nothing:
 * delivery is already closed and the hold either ends or becomes a deletion.
 */
export function mediaSuppressionsFor(
  pointer: PublicationPointer,
  attachments: readonly {
    readonly assetId: EntityId;
    readonly sourceGeneration: string;
    readonly variantManifestRevision: string;
  }[],
  states: readonly AttachedMediaState[],
): readonly MediaSuppressionV1[] {
  const confirmed = mediaConfirmationsOf(pointer);
  const needed: MediaSuppressionV1[] = [];
  for (const attachment of attachments) {
    const state = states.find((item) => item.assetId === attachment.assetId);
    const epoch = state?.revocationEpoch ?? 0;
    if (state === undefined || state.state === 'absent' || state.state === 'deleted') {
      needed.push({ assetId: attachment.assetId, reason: 'deleted', observedEpoch: epoch });
      continue;
    }
    const confirmation = confirmed.find((item) => item.assetId === attachment.assetId);
    const revoked =
      state.state === 'restricted' ||
      state.state === 'not_ready' ||
      confirmation === undefined ||
      confirmation.revocationEpoch !== state.revocationEpoch ||
      state.sourceGeneration !== attachment.sourceGeneration ||
      state.variantManifestRevision !== attachment.variantManifestRevision;
    if (revoked)
      needed.push({ assetId: attachment.assetId, reason: 'revoked', observedEpoch: epoch });
  }
  return needed;
}

/**
 * Adds suppressions of attached media that Media revoked or deleted after the
 * publisher confirmed it (D2 §5.2). Suppression only grows here; nothing else of
 * the pointer changes, and an addition already present is not a new revision.
 */
export function suppressMedia(
  current: PublicationPointer,
  additions: readonly MediaSuppressionV1[],
  nowUtc: UtcInstant,
): PublicationPointer {
  const existing = mediaSuppressionOf(current);
  const fresh = additions.filter(
    (item) => !existing.some((stored) => stored.assetId === item.assetId),
  );
  if (fresh.length === 0) return current;
  return next(
    current,
    {
      ownerHold: current.ownerHold,
      moderationHold: current.moderationHold,
      mediaSuppression: [...existing, ...fresh],
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
