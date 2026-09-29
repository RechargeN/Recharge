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
  readonly createdByUserId: EntityId;
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
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly revision: number;
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
}

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
  readonly publishedAtUtc: UtcInstant;
}

export interface PublicationPointerV1 {
  readonly schemaVersion: 1;
  readonly contentId: EntityId;
  readonly currentPublishedRevisionId: EntityId | null;
  readonly previousPublishedRevisionId: EntityId | null;
  readonly visibility: 'visible' | 'withdrawn';
  readonly revision: number;
  readonly updatedAtUtc: UtcInstant;
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
  | 'market_disabled'
  | 'policy_unavailable'
  | 'revision_conflict'
  | 'idempotency_conflict'
  | 'unsupported_version'
  | 'unknown_outcome'
  | 'not_found'
  | 'invalid_contract';

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
  }
>;
export type UpdateDraftCommandV1 = CommandEnvelope<
  'updateDraft',
  { readonly draftId: EntityId; readonly expectedRevision: number; readonly body: ContentBody }
>;
export type SubmitForPublicationCommandV1 = CommandEnvelope<
  'submitForPublication',
  { readonly draftId: EntityId; readonly expectedDraftRevision: number }
>;
export type PublishApprovedRevisionCommandV1 = CommandEnvelope<
  'publishApprovedRevision',
  { readonly submissionId: EntityId; readonly expectedPointerRevision: number }
>;
export type ContentCommandV1 =
  | CreateDraftCommandV1
  | UpdateDraftCommandV1
  | SubmitForPublicationCommandV1
  | PublishApprovedRevisionCommandV1;

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

export interface PublicationStatusV1 {
  readonly contentId: EntityId;
  readonly pointer: PublicationPointerV1 | null;
  readonly submissions: readonly PublicationSubmissionV1[];
}

/** Committed, minimized fact for downstream consumers (Catalog, Booking reader). */
export interface ContentEffectV1 {
  readonly schemaVersion: 1;
  readonly effectId: string;
  readonly kind: 'ContentPublished' | 'ContentRevisionActivated';
  readonly contentId: EntityId;
  readonly publishedRevisionId: EntityId;
  readonly typeId: ContentTypeId;
  readonly publisherRef: PublisherRefV1;
  readonly marketId: MarketId;
  readonly referenceRevisions: ContentReferenceRevisionsV1;
  readonly occurredAtUtc: UtcInstant;
}
