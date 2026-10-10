import type { EntityId } from '../shared/ids.js';
import type { UtcInstant } from '../shared/utc_instant.js';
import type { MarketId } from '../modules/reference_data/domain/identifiers.js';
import type { PublisherRefV1 } from './identity_v1.js';

export const contentTypeIds = [
  'event',
  'activity',
  'route',
  'place',
  'session',
  'scenario',
  'find_people',
  'class_workshop',
  'rental',
  'collection',
] as const;
export type ContentTypeId = (typeof contentTypeIds)[number];

export type ContentDraftStatus = 'editing' | 'ready' | 'submitted' | 'revision_requested';
export type PublicationSubmissionState =
  | 'submitted'
  | 'under_review'
  | 'revision_requested'
  | 'rejected'
  | 'approved_for_publication'
  | 'published'
  | 'superseded';

export type ContentBody = Readonly<Record<string, unknown>>;

/** Typed reason a source revision differs from what is public (BCK-07 §7.4). */
export type ChangeClass =
  | 'new'
  | 'operationalSchedule'
  | 'venueChange'
  | 'operationalCancellation'
  | 'operationalPostponement'
  | 'commercial'
  | 'contentMinor'
  | 'contentMajor'
  | 'occurrenceAdded';

export interface DirectOriginBindingV1 {
  readonly kind: 'directAuthoring';
}
export interface DelegatedOriginBindingV1 {
  readonly kind: 'delegatedImport';
  /** `module:<module>/<operation>` of the approved server module. */
  readonly delegatedActorRef: string;
  readonly externalBindingRef: string;
}

/**
 * Immutable-by-origin provenance. A direct submission names the authenticated
 * user; an owner import names the approved module, the exact source and its
 * binding. No field is fabricated when the source did not supply it.
 */
export type ContentProvenanceV1 =
  | {
      readonly kind: 'creatorSubmission';
      readonly importerActorRef: string;
      readonly originBinding: DirectOriginBindingV1;
    }
  | {
      readonly kind: 'ownerImport';
      readonly sourceId: string;
      readonly sourceRevision: string;
      readonly snapshotHash?: string;
      readonly sourceUrlRef?: string;
      readonly acquiredAtUtc: UtcInstant;
      readonly checkedAtUtc?: UtcInstant;
      readonly correctionRemovalPolicyRef: string;
      readonly importerActorRef: string;
      readonly originBinding: DelegatedOriginBindingV1;
    };

/** Input of `createDraft` that is only honoured for an approved delegated module. */
export interface DelegatedOriginV1 {
  readonly kind: 'delegatedImport';
  readonly delegatedActorRef: string;
  readonly externalBindingRef: string;
  readonly sourceId: string;
  readonly sourceRevision: string;
  readonly snapshotHash?: string;
  readonly sourceUrlRef?: string;
  readonly acquiredAtUtc: UtcInstant;
  readonly checkedAtUtc?: UtcInstant;
  readonly correctionRemovalPolicyRef: string;
}

export interface SourceRefreshV1 {
  readonly sourceRevision: string;
  readonly snapshotHash?: string;
  readonly checkedAtUtc?: UtcInstant;
}

export interface ContentReferenceRevisionsV1 {
  readonly marketConfigRevisionId: string;
  readonly taxonomyRevisionId: string;
  readonly localizationRevisionId: string;
}

export interface ContentDraftV1 {
  readonly schemaVersion: 1;
  readonly draftId: EntityId;
  readonly contentId: EntityId;
  readonly typeId: ContentTypeId;
  readonly typeSchemaMajor: 1;
  readonly publisherRef: PublisherRefV1;
  readonly publisherBindingOrigin: PublisherRefV1;
  readonly marketId: MarketId;
  readonly status: ContentDraftStatus;
  readonly revision: number;
  readonly body: ContentBody;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  /** Authoring user; null for a delegated import (see `provenance`). */
  readonly createdByUserId: EntityId | null;
  readonly provenance: ContentProvenanceV1;
  readonly importSourceKey?: string;
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
}

export interface PublicationSubmissionV1 {
  readonly schemaVersion: 1;
  readonly submissionId: EntityId;
  readonly draftId: EntityId;
  readonly contentId: EntityId;
  readonly draftRevision: number;
  readonly typeId: ContentTypeId;
  readonly publisherRef: PublisherRefV1;
  readonly marketId: MarketId;
  readonly state: PublicationSubmissionState;
  readonly moderation: {
    readonly profileId: string;
    readonly requiresPrePublicationModeration: boolean;
    readonly policyRevision: string;
    readonly policyDecisionId?: string;
  };
  readonly eligibilityAuthorityRevision: number;
  readonly changeClass?: ChangeClass;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly revision: number;
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
}

/**
 * Generation-pinned reference to a ready Media asset, stored in the immutable
 * revision by the owning domain (BCK-14 §8.2, BCK-07 v0.11 §37).
 */
export interface MediaAttachmentV1 {
  readonly assetId: EntityId;
  readonly sourceGeneration: string;
  readonly variantManifestRevision: string;
  readonly purpose: 'contentMedia';
}

/**
 * The Media revocation epoch the publisher confirmed for an attached asset at
 * publish or activation (D2 §3, §5.1). Kept in the pointer, never in the
 * immutable revision or its `mediaRevision` hash.
 */
export interface MediaConfirmationV1 {
  readonly assetId: EntityId;
  readonly revocationEpoch: number;
}

/**
 * An attached asset Content stopped showing because Media revoked it after
 * confirmation (`revoked`) or deleted it (`deleted`). Only an activation by the
 * publisher clears it (D2 §5.4).
 */
export interface MediaSuppressionV1 {
  readonly assetId: EntityId;
  readonly reason: 'revoked' | 'deleted';
  readonly observedEpoch: number;
}

/** Internal reasons; every one is the public failure `media_not_ready`. */
export type MediaNotReadyReason =
  | 'asset_unknown'
  | 'foreign_binding'
  | 'stale_generation'
  | 'deleted'
  | 'restricted'
  | 'not_ready'
  | 'policy_unavailable';

export interface PublishedRevisionV1 {
  readonly schemaVersion: 1;
  readonly contentId: EntityId;
  readonly publishedRevisionId: EntityId;
  readonly revisionNumber: number;
  readonly draftId: EntityId;
  readonly submissionId: EntityId;
  readonly typeId: ContentTypeId;
  readonly publisherRef: PublisherRefV1;
  readonly marketId: MarketId;
  readonly body: ContentBody;
  readonly bodyHash: string;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly mediaRevision: string;
  readonly mediaAttachments: readonly MediaAttachmentV1[];
  readonly provenance: ContentProvenanceV1;
  readonly publishedAtUtc: UtcInstant;
}

/** Effective visibility, derived from the owner and moderation holds below. */
export type PublicationVisibility = 'visible' | 'withdrawn' | 'restricted' | 'archived';
export type OwnerHold = 'withdrawn' | 'archived';
export interface ModerationHold {
  readonly kind: 'restricted' | 'withdrawn';
  /** Decision that placed the hold; only its chain can lift it. */
  readonly decisionId: string;
}

/**
 * The pointer carries two independent holds so that lifting one never lifts
 * the other: a moderation restore cannot republish what the owner withdrew, and
 * an owner republish cannot bypass a moderation decision.
 */
export interface PublicationPointerV1 {
  readonly schemaVersion: 1;
  readonly contentId: EntityId;
  readonly currentPublishedRevisionId: EntityId | null;
  readonly previousPublishedRevisionId: EntityId | null;
  readonly visibility: PublicationVisibility;
  readonly ownerHold: OwnerHold | null;
  readonly moderationHold: ModerationHold | null;
  readonly revision: number;
  readonly updatedAtUtc: UtcInstant;
  /** D2: stored only when non-empty; absent means none. */
  readonly mediaConfirmations?: readonly MediaConfirmationV1[];
  /** D2: stored only when non-empty; grows until the publisher activates again. */
  readonly mediaSuppression?: readonly MediaSuppressionV1[];
}

export type ContentFailureCode =
  | 'unauthenticated'
  | 'capability_denied'
  | 'publisher_not_eligible'
  | 'creator_verification_required'
  | 'membership_inactive'
  | 'type_disabled'
  | 'content_type_unsupported'
  | 'source_revision_stale'
  | 'validation_failed'
  | 'media_not_ready'
  | 'moderation_required'
  | 'moderation_decision_stale'
  | 'publication_restricted'
  | 'market_disabled'
  | 'policy_unavailable'
  | 'revision_conflict'
  | 'idempotency_conflict'
  | 'unsupported_version'
  | 'unknown_outcome'
  | 'not_found'
  | 'invalid_contract'
  | 'storage_limit_exceeded';

interface CommandEnvelope<Type extends string, Payload> {
  readonly schemaVersion: 1;
  readonly commandType: Type;
  readonly idempotencyKey: string;
  readonly payload: Payload;
}

export type CreateDraftCommandV1 = CommandEnvelope<
  'createDraft',
  {
    readonly typeId: ContentTypeId;
    readonly publisherRef: PublisherRefV1;
    readonly marketId: MarketId;
    readonly body: ContentBody;
    readonly importSourceKey?: string;
    readonly origin?: DelegatedOriginV1;
  }
>;
export type UpdateDraftCommandV1 = CommandEnvelope<
  'updateDraft',
  {
    readonly draftId: EntityId;
    readonly expectedRevision: number;
    readonly body: ContentBody;
    readonly sourceRefresh?: SourceRefreshV1;
  }
>;
export type SubmitForPublicationCommandV1 = CommandEnvelope<
  'submitForPublication',
  {
    readonly draftId: EntityId;
    readonly expectedDraftRevision: number;
    readonly changeClass?: ChangeClass;
  }
>;
export type PublishApprovedRevisionCommandV1 = CommandEnvelope<
  'publishApprovedRevision',
  { readonly submissionId: EntityId; readonly expectedPointerRevision: number }
>;
export type WithdrawPublicationCommandV1 = CommandEnvelope<
  'withdrawPublication',
  {
    readonly contentId: EntityId;
    readonly expectedPointerRevision: number;
    readonly mode: 'withdraw' | 'archive';
  }
>;
export type ActivatePublishedRevisionCommandV1 = CommandEnvelope<
  'activatePublishedRevision',
  {
    readonly contentId: EntityId;
    readonly publishedRevisionId: EntityId;
    readonly expectedPointerRevision: number;
  }
>;

export type ModerationDispositionKind =
  'approve' | 'request_revision' | 'reject' | 'restrict' | 'withdraw' | 'restore';

/**
 * Typed BCK-22 enforcement instruction. It is not a client command: it is only
 * accepted through the verified system path and never through `execute`.
 */
export type ApplyModerationDispositionCommandV1 = CommandEnvelope<
  'applyModerationDisposition',
  {
    readonly instructionId: string;
    readonly decisionId: string;
    readonly policyRevision: string;
    readonly disposition: ModerationDispositionKind;
    readonly target: {
      readonly contentId: EntityId;
      readonly submissionId?: EntityId;
      readonly publishedRevisionId?: EntityId;
    };
    readonly reasonCategory: string;
    /** For `restore`: the decision whose hold is being lifted. */
    readonly restoresDecisionId?: string;
    readonly effectiveAtUtc: UtcInstant;
    readonly attestation: string;
  }
>;

/** Commands a signed-in actor may issue through `ContentPublicationService.execute`. */
export type ContentCommandV1 =
  | CreateDraftCommandV1
  | UpdateDraftCommandV1
  | SubmitForPublicationCommandV1
  | PublishApprovedRevisionCommandV1
  | WithdrawPublicationCommandV1
  | ActivatePublishedRevisionCommandV1;

export interface ModerationAcknowledgementV1 {
  readonly instructionId: string;
  readonly decisionId: string;
  readonly outcome: 'applied' | 'already_applied';
  readonly disposition: ModerationDispositionKind;
  readonly contentId: EntityId;
  readonly pointerRevision: number | null;
}

export type ContentQueryV1 =
  | {
      readonly schemaVersion: 1;
      readonly queryType: 'getDraft';
      readonly payload: { readonly draftId: EntityId };
    }
  | {
      readonly schemaVersion: 1;
      readonly queryType: 'getPublicationStatus' | 'getPublishedRevision';
      readonly payload: { readonly contentId: EntityId };
    };

export type ContentQueryByBindingV1 = {
  readonly schemaVersion: 1;
  readonly queryType: 'findByExternalBinding';
  readonly payload: { readonly externalBindingRef: string };
};

export interface ExternalBindingLookupV1 {
  readonly externalBindingRef: string;
  readonly draft: ContentDraftV1;
  readonly pointer: PublicationPointerV1 | null;
  readonly currentRevision: PublishedRevisionV1 | null;
}

export interface PublicationStatusV1 {
  readonly contentId: EntityId;
  readonly pointer: PublicationPointerV1 | null;
  readonly submissions: readonly PublicationSubmissionV1[];
}

/**
 * Committed, minimized fact for downstream consumers (Catalog, Booking reader).
 * `pointerRevision` is monotonic per content, so a consumer can always tell a
 * newer visibility fact from a stale replay and tombstones defeat stale caches.
 */
export interface ContentEffectV1 {
  readonly schemaVersion: 1;
  readonly effectId: string;
  readonly kind:
    | 'ContentPublished'
    | 'ContentRevisionActivated'
    | 'ContentVisibilityChanged'
    /** D2: only the media the pointer suppresses changed; no Booking fact. */
    | 'ContentMediaAvailabilityChanged';
  readonly contentId: EntityId;
  readonly publishedRevisionId: EntityId;
  readonly pointerRevision: number;
  readonly visibility: PublicationVisibility;
  readonly typeId: ContentTypeId;
  readonly publisherRef: PublisherRefV1;
  readonly marketId: MarketId;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly occurredAtUtc: UtcInstant;
  /** D2: media the pointer suppresses at this fact; absent when none. */
  readonly suppressedMediaIds?: readonly EntityId[];
}
