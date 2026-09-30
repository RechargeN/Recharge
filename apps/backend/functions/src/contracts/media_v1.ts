import type { EntityId } from '../shared/ids.js';
import type { UtcInstant } from '../shared/utc_instant.js';
import type { MarketId } from '../modules/reference_data/domain/identifiers.js';
import type { PublisherRefV1 } from './identity_v1.js';

export const mediaFamilies = ['image', 'video', 'audio', 'document', 'gpx'] as const;
export type MediaFamily = (typeof mediaFamilies)[number];

export type MediaVisibilityClass = 'private' | 'protected' | 'publicDerived';

/** Unified lifecycle of BCK-14 v0.4 §34.3. */
export const mediaLifecycles = [
  'reserved',
  'uploading',
  'uploaded',
  'validating',
  'quarantined',
  'processing',
  'ready',
  'blocked',
  'deleting',
  'deleted',
] as const;
export type MediaLifecycle = (typeof mediaLifecycles)[number];

export type UploadSessionState = 'open' | 'completed' | 'expired' | 'aborted';

/** Local slice: only Content may bind media; other domains fail closed. */
export interface MediaEntityBindingV1 {
  readonly domain: 'content';
  readonly entityId: EntityId;
  readonly purpose: 'contentMedia';
}

/**
 * Pinned source object. The provider object key never appears in the contract:
 * the backend selects and keeps it (BCK-14 §7.2).
 */
export interface ObjectGenerationRefV1 {
  readonly providerGeneration: string;
  readonly byteLength: number;
  readonly verifiedMediaType: string;
  readonly sha256: string;
  readonly validationProfileRevision: string;
}

export interface MediaVariantRefV1 {
  readonly variantId: EntityId;
  readonly profile: string;
  readonly format: string;
  readonly providerGeneration: string;
  readonly sha256: string;
  readonly byteLength: number;
  readonly transformProfileRevision: string;
  readonly sourceProviderGeneration: string;
  readonly width?: number;
  readonly height?: number;
  readonly durationMs?: number;
}

export interface MediaAssetV1 {
  readonly schemaVersion: 1;
  readonly assetId: EntityId;
  readonly ownerSubjectId: EntityId;
  readonly publisherRef?: PublisherRefV1;
  readonly entityBinding?: MediaEntityBindingV1;
  readonly marketId: MarketId;
  readonly family: MediaFamily;
  readonly visibilityClass: MediaVisibilityClass;
  readonly lifecycle: MediaLifecycle;
  readonly sourceGenerationRef?: ObjectGenerationRefV1;
  /** SHA-256 of the canonical variant manifest; present only when `ready`. */
  readonly variantManifestRevision?: string;
  readonly variantRefs: readonly MediaVariantRefV1[];
  readonly policyRevision: string;
  /** Set first by delete/restrict; a late result can never undo it. */
  readonly deliveryDisabled: boolean;
  /** An authoritative (Security/Trust) restriction; only a verified instruction changes it. */
  readonly restricted?: boolean;
  /** A temporary hold a deletion placed itself; released alone, never the restriction. */
  readonly deletionHold?: boolean;
  readonly attemptCount: number;
  readonly revision: number;
  readonly createdAtUtc: UtcInstant;
  readonly updatedAtUtc: UtcInstant;
  readonly deletedAtUtc?: UtcInstant;
  /** Since when no owning domain references this asset (orphan grace clock). */
  readonly orphanSinceUtc?: UtcInstant;
}

export interface UploadSessionV1 {
  readonly schemaVersion: 1;
  readonly uploadSessionId: EntityId;
  readonly assetId: EntityId;
  readonly ownerSubjectId: EntityId;
  readonly publisherRef?: PublisherRefV1;
  readonly entityIntent?: MediaEntityBindingV1;
  readonly marketId: MarketId;
  readonly allowedFamily: MediaFamily;
  readonly allowedMediaTypes: readonly string[];
  readonly maxBytes: number;
  readonly expiresAtUtc: UtcInstant;
  readonly state: UploadSessionState;
  readonly revision: number;
  readonly createdAtUtc: UtcInstant;
  readonly completedAtUtc?: UtcInstant;
}

export type ScanResult = 'clean' | 'rejected' | 'inconclusive';
export type ProcessingResult = 'succeeded' | 'failed' | 'rejected';

/** Pins input, tool and policy so a retry can never overwrite a different input. */
export interface ProcessingReceiptV1 {
  readonly schemaVersion: 1;
  readonly assetId: EntityId;
  readonly attemptNumber: number;
  readonly sourceProviderGeneration: string;
  readonly sourceSha256: string;
  readonly policyRevision: string;
  readonly scan: { readonly toolRevision: string; readonly result: ScanResult };
  readonly processing?: {
    readonly toolRevision: string;
    readonly result: ProcessingResult;
    readonly variantManifestRevision?: string;
  };
  readonly outcome: 'ready' | 'quarantined' | 'blocked';
  readonly startedAtUtc: UtcInstant;
  readonly completedAtUtc: UtcInstant;
}

export interface EntityIntentV1 {
  readonly domain: 'content';
  readonly entityId: EntityId;
  readonly purpose: 'contentMedia';
}

export interface CreateUploadSessionCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'createUploadSession';
  readonly idempotencyKey: string;
  readonly payload: {
    readonly family: MediaFamily;
    readonly marketId: MarketId;
    readonly visibilityClass: MediaVisibilityClass;
    readonly declaredMediaType: string;
    readonly declaredByteLength: number;
    readonly publisherRef?: PublisherRefV1;
    readonly entityIntent?: EntityIntentV1;
  };
}
export interface ConfirmUploadCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'confirmUpload';
  readonly idempotencyKey: string;
  readonly payload: {
    readonly uploadSessionId: EntityId;
    readonly expectedSha256: string;
    readonly expectedByteLength: number;
  };
}
export interface FinalizeAssetCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'finalizeAsset';
  readonly idempotencyKey: string;
  readonly payload: {
    readonly assetId: EntityId;
    readonly expectedAssetRevision: number;
    readonly sourceProviderGeneration: string;
    readonly expectedSha256: string;
    readonly expectedByteLength: number;
  };
}
export interface RetryProcessingCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'retryProcessing';
  readonly idempotencyKey: string;
  readonly payload: {
    readonly assetId: EntityId;
    readonly expectedAssetRevision: number;
    readonly sourceProviderGeneration: string;
  };
}
export interface DeleteAssetCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'deleteAsset';
  readonly idempotencyKey: string;
  readonly payload: { readonly assetId: EntityId; readonly expectedAssetRevision: number };
}
export interface DetachAssetCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'detachAsset';
  readonly idempotencyKey: string;
  readonly payload: { readonly assetId: EntityId; readonly expectedAssetRevision: number };
}
/** System-only: an authoritative privacy/moderation/security input, never a user command. */
export interface ApplyRestrictionCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'applyRestriction';
  readonly idempotencyKey: string;
  readonly payload: {
    readonly assetId: EntityId;
    readonly decisionRef: string;
    readonly restricted: boolean;
  };
}
/** System-only: cleanup worker instruction. */
export interface ReconcileOrphanCommandV1 {
  readonly schemaVersion: 1;
  readonly commandType: 'reconcileOrphan';
  readonly idempotencyKey: string;
  readonly payload: { readonly assetId: EntityId };
}
export type MediaCommandV1 =
  | CreateUploadSessionCommandV1
  | ConfirmUploadCommandV1
  | FinalizeAssetCommandV1
  | RetryProcessingCommandV1
  | DeleteAssetCommandV1
  | DetachAssetCommandV1
  | ApplyRestrictionCommandV1
  | ReconcileOrphanCommandV1;

export interface GetAssetStatusQueryV1 {
  readonly schemaVersion: 1;
  readonly queryType: 'getAssetStatus';
  readonly payload: { readonly assetId: EntityId };
}
export interface GetProcessingReceiptQueryV1 {
  readonly schemaVersion: 1;
  readonly queryType: 'getProcessingReceipt';
  readonly payload: { readonly assetId: EntityId; readonly attemptNumber?: number };
}
export interface GetDeletionStatusQueryV1 {
  readonly schemaVersion: 1;
  readonly queryType: 'getDeletionStatus';
  readonly payload: { readonly assetId: EntityId };
}
export type MediaQueryV1 =
  GetAssetStatusQueryV1 | GetProcessingReceiptQueryV1 | GetDeletionStatusQueryV1;

export type DeletionReason = 'owner_request' | 'orphan_cleanup' | 'expired_upload';

/** Privacy-safe deletion task status: ids, state and times only. */
export interface MediaDeletionStatusV1 {
  readonly schemaVersion: 1;
  readonly assetId: EntityId;
  readonly state: 'pending' | 'completed';
  readonly reason: DeletionReason;
  readonly deletionRevision: number;
  readonly requestedAtUtc: UtcInstant;
  readonly completedAtUtc?: UtcInstant;
}

export interface OrphanReconciliationV1 {
  readonly schemaVersion: 1;
  readonly assetId: EntityId;
  readonly action: 'keep' | 'marked' | 'unmarked' | 'deleting' | 'deleted' | 'recovered';
  readonly assetRevision: number;
}

/**
 * Versioned fact for Catalog/owning domains: ids and revisions only, never
 * bytes, URLs or object keys. The monotonic `assetRevision` lets a tombstone
 * beat a stale cache.
 */
export interface MediaEffectV1 {
  readonly schemaVersion: 1;
  readonly effectId: string;
  readonly type:
    'MediaAssetReady' | 'MediaDeliveryDisabled' | 'MediaDeliveryRestored' | 'MediaAssetDeleted';
  readonly assetId: EntityId;
  readonly assetRevision: number;
  readonly occurredAtUtc: UtcInstant;
}

export const mediaFailureCodes = [
  'unauthenticated',
  'invalid_contract',
  'unsupported_version',
  'capability_denied',
  'membership_inactive',
  'market_disabled',
  'not_found',
  'policy_unavailable',
  'family_unavailable',
  'entity_scope_denied',
  'session_expired',
  'object_missing',
  'upload_incomplete',
  'generation_mismatch',
  'signature_mismatch',
  'limit_exceeded',
  'stale_revision',
  'invalid_state',
  'idempotency_conflict',
  'retry_not_allowed',
  'revision_conflict',
  'unknown_outcome',
  'asset_referenced',
] as const;
export type MediaFailureCode = (typeof mediaFailureCodes)[number];
