import type {
  ChangeClass,
  ContentReferenceRevisionsV1,
  ModerationDispositionKind,
  PublicationSubmissionV1,
} from '../../../contracts/content_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';
import type { ContentDraft } from './content_draft.js';
import { ContentDomainRefusal } from './failures.js';

export type PublicationSubmission = DeepReadonly<PublicationSubmissionV1>;

export function createPublicationSubmission(input: {
  readonly submissionId: EntityId;
  readonly draft: ContentDraft;
  readonly moderation: {
    readonly profileId: string;
    readonly requiresPrePublicationModeration: boolean;
    readonly policyRevision: string;
    readonly policyDecisionId?: string;
  };
  readonly eligibilityAuthorityRevision: number;
  readonly changeClass?: ChangeClass;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly nowUtc: UtcInstant;
}): PublicationSubmission {
  const needsReview = input.moderation.requiresPrePublicationModeration;
  // A type without pre-publication moderation still moves through
  // `submitted` -> `approved_for_publication` via a recorded policy decision;
  // it never skips the state.
  if (!needsReview && input.moderation.policyDecisionId === undefined)
    throw new ContentDomainRefusal('policy_unavailable');
  return deepFreeze({
    schemaVersion: 1,
    submissionId: input.submissionId,
    draftId: input.draft.draftId,
    contentId: input.draft.contentId,
    draftRevision: input.draft.revision,
    typeId: input.draft.typeId,
    publisherRef: { ...input.draft.publisherRef },
    marketId: input.draft.marketId,
    state: needsReview ? 'under_review' : 'approved_for_publication',
    moderation: { ...input.moderation },
    eligibilityAuthorityRevision: input.eligibilityAuthorityRevision,
    ...(input.changeClass === undefined ? {} : { changeClass: input.changeClass }),
    referenceRevisions: { ...input.referenceRevisions },
    revision: 1,
    createdAtUtc: input.nowUtc,
    updatedAtUtc: input.nowUtc,
  } satisfies PublicationSubmissionV1);
}

export function assertPublishable(submission: PublicationSubmission): void {
  switch (submission.state) {
    case 'approved_for_publication':
      return;
    case 'submitted':
    case 'under_review':
      throw new ContentDomainRefusal('moderation_required');
    case 'rejected':
    case 'revision_requested':
      throw new ContentDomainRefusal('moderation_decision_stale');
    case 'published':
    case 'superseded':
      throw new ContentDomainRefusal('revision_conflict');
  }
}

export function withSubmissionState(
  submission: PublicationSubmission,
  state: 'published' | 'superseded',
  nowUtc: UtcInstant,
): PublicationSubmission {
  return deepFreeze({
    ...structuredClone(submission),
    state,
    revision: submission.revision + 1,
    updatedAtUtc: nowUtc,
  });
}

export type ReviewDisposition = Extract<
  ModerationDispositionKind,
  'approve' | 'request_revision' | 'reject'
>;

/**
 * Apply a verified pre-publication review outcome to the exact submission.
 * Only a submission that is still under review can change; anything else is a
 * stale or foreign decision and mutates nothing. A rejected or revision-requested
 * submission never reaches an earlier published revision.
 */
export function applyReviewDisposition(
  submission: PublicationSubmission,
  disposition: ReviewDisposition,
  decisionId: string,
  nowUtc: UtcInstant,
): PublicationSubmission {
  if (submission.state !== 'under_review')
    throw new ContentDomainRefusal('moderation_decision_stale');
  const state =
    disposition === 'approve'
      ? 'approved_for_publication'
      : disposition === 'reject'
        ? 'rejected'
        : 'revision_requested';
  return deepFreeze({
    ...structuredClone(submission),
    state,
    moderation: { ...structuredClone(submission.moderation), policyDecisionId: decisionId },
    revision: submission.revision + 1,
    updatedAtUtc: nowUtc,
  });
}
