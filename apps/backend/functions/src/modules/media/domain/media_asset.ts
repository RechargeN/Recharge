import { createHash } from 'node:crypto';

import type {
  MediaAssetV1,
  MediaEntityBindingV1,
  MediaFamily,
  MediaLifecycle,
  MediaVariantRefV1,
  MediaVisibilityClass,
  ObjectGenerationRefV1,
} from '../../../contracts/media_v1.js';
import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';
import { MediaDomainRefusal } from './failures.js';
import type { VariantManifest } from './media_variant.js';

/**
 * Stored asset: the wire view plus fields that never leave the module — the
 * backend-selected object key handle and the D2 revocation marker
 * (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §3).
 */
export type MediaAsset = DeepReadonly<MediaAssetV1> & {
  readonly objectKeyHandle: string;
  /**
   * Monotonic: +1 whenever a restriction decision is applied or deletion starts;
   * lifting a restriction never lowers it. Absent means 0.
   */
  readonly revocationEpoch?: number;
  /** The decision behind the active restriction; only its own restore lifts it. */
  readonly restrictionDecisionRef?: string;
};

/** The revocation epoch of an asset (absent = 0). */
export function revocationEpochOf(asset: MediaAsset): number {
  return asset.revocationEpoch ?? 0;
}

/** Deterministic JSON with sorted object keys (used for hashes only). */
export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value) ?? 'null';
  if (Array.isArray(value)) return `[${value.map((item) => canonicalJson(item)).join(',')}]`;
  const record = value as Record<string, unknown>;
  return `{${Object.keys(record)
    .filter((key) => record[key] !== undefined)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalJson(record[key])}`)
    .join(',')}}`;
}

export function sha256Hex(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

/**
 * The only lifecycle transitions that exist (BCK-14 v0.4 §34.3). Anything not
 * listed is forbidden, including leaving `quarantined` other than by an explicit
 * retry or deletion.
 */
export const lifecycleTransitions: Readonly<Record<MediaLifecycle, readonly MediaLifecycle[]>> = {
  reserved: ['uploading', 'deleted', 'deleting'],
  uploading: ['uploaded', 'deleted', 'deleting'],
  uploaded: ['validating'],
  validating: ['processing', 'quarantined', 'blocked'],
  quarantined: ['validating', 'deleting'],
  processing: ['ready', 'quarantined', 'blocked'],
  ready: ['deleting'],
  blocked: ['deleting'],
  deleting: ['deleted'],
  deleted: [],
};

/** Moves that must never happen on an asset whose delivery is disabled. */
const blockedWhenDisabled: ReadonlySet<MediaLifecycle> = new Set([
  'validating',
  'processing',
  'ready',
]);

function assertPath(asset: MediaAsset, path: readonly MediaLifecycle[]): void {
  let current = asset.lifecycle;
  for (const next of path) {
    if (!lifecycleTransitions[current].includes(next))
      throw new MediaDomainRefusal('invalid_state');
    if (asset.deliveryDisabled && blockedWhenDisabled.has(next))
      throw new MediaDomainRefusal('invalid_state');
    current = next;
  }
}

export interface CreateReservedAssetInput {
  readonly assetId: EntityId;
  readonly ownerSubjectId: EntityId;
  readonly publisherRef?: PublisherRefV1;
  readonly entityBinding?: MediaEntityBindingV1;
  readonly marketId: MarketId;
  readonly family: MediaFamily;
  readonly visibilityClass: MediaVisibilityClass;
  readonly policyRevision: string;
  readonly objectKeyHandle: string;
  readonly nowUtc: UtcInstant;
}

export function createReservedAsset(input: CreateReservedAssetInput): MediaAsset {
  return deepFreeze({
    schemaVersion: 1,
    assetId: input.assetId,
    ownerSubjectId: input.ownerSubjectId,
    ...(input.publisherRef === undefined ? {} : { publisherRef: input.publisherRef }),
    ...(input.entityBinding === undefined ? {} : { entityBinding: input.entityBinding }),
    marketId: input.marketId,
    family: input.family,
    visibilityClass: input.visibilityClass,
    lifecycle: 'reserved',
    variantRefs: [],
    policyRevision: input.policyRevision,
    deliveryDisabled: false,
    attemptCount: 0,
    revision: 1,
    createdAtUtc: input.nowUtc,
    updatedAtUtc: input.nowUtc,
    objectKeyHandle: input.objectKeyHandle,
  });
}

interface AdvancePatch {
  readonly sourceGenerationRef?: ObjectGenerationRefV1;
  readonly variantRefs?: readonly MediaVariantRefV1[];
  readonly variantManifestRevision?: string;
  readonly attemptCount?: number;
  readonly deliveryDisabled?: boolean;
  readonly restricted?: boolean;
  readonly deletionHold?: DeletionHold;
  readonly deletedAtUtc?: UtcInstant;
  readonly revocationEpoch?: number;
}

/**
 * Applies a whole lifecycle path in one revision bump. Every hop must exist in
 * the table; a disabled asset can never move back towards `ready`.
 */
export function advance(
  asset: MediaAsset,
  path: readonly MediaLifecycle[],
  nowUtc: UtcInstant,
  patch: AdvancePatch = {},
): MediaAsset {
  assertPath(asset, path);
  const last = path[path.length - 1];
  if (last === undefined) throw new MediaDomainRefusal('invalid_state');
  return deepFreeze({
    ...asset,
    ...patch,
    lifecycle: last,
    revision: asset.revision + 1,
    updatedAtUtc: nowUtc,
  });
}

/** `reserved`/`uploading` with a complete, verified object -> `validating` with the generation pinned. */
export function acceptSource(
  asset: MediaAsset,
  source: ObjectGenerationRefV1,
  nowUtc: UtcInstant,
): MediaAsset {
  const path: MediaLifecycle[] =
    asset.lifecycle === 'reserved'
      ? ['uploading', 'uploaded', 'validating']
      : ['uploaded', 'validating'];
  return advance(asset, path, nowUtc, { sourceGenerationRef: source });
}

/** First accepted bytes of an unfinished upload: `reserved` -> `uploading`. */
export function markUploading(asset: MediaAsset, nowUtc: UtcInstant): MediaAsset {
  return advance(asset, ['uploading'], nowUtc);
}

/** Records the start of a processing attempt without changing the lifecycle. */
export function startAttempt(asset: MediaAsset, nowUtc: UtcInstant): MediaAsset {
  if (asset.lifecycle !== 'validating' || asset.deliveryDisabled)
    throw new MediaDomainRefusal('invalid_state');
  return deepFreeze({
    ...asset,
    attemptCount: asset.attemptCount + 1,
    revision: asset.revision + 1,
    updatedAtUtc: nowUtc,
  });
}

/**
 * Explicit exit from quarantine: the same source generation, an asset that is
 * not disabled, and an attempt budget left. Creates a new attempt only.
 */
export function retryFromQuarantine(
  asset: MediaAsset,
  sourceProviderGeneration: string,
  maxAttempts: number,
  nowUtc: UtcInstant,
): MediaAsset {
  if (asset.lifecycle !== 'quarantined') throw new MediaDomainRefusal('retry_not_allowed');
  if (asset.deliveryDisabled) throw new MediaDomainRefusal('retry_not_allowed');
  if (asset.sourceGenerationRef?.providerGeneration !== sourceProviderGeneration)
    throw new MediaDomainRefusal('generation_mismatch');
  if (asset.attemptCount >= maxAttempts) throw new MediaDomainRefusal('retry_not_allowed');
  return advance(asset, ['validating'], nowUtc, { attemptCount: asset.attemptCount + 1 });
}

/** Only a trusted processor path calls this, after every mandatory check passed. */
export function markReady(
  asset: MediaAsset,
  manifest: Extract<VariantManifest, { ok: true }>,
  nowUtc: UtcInstant,
): MediaAsset {
  return advance(asset, ['ready'], nowUtc, {
    variantRefs: manifest.variants,
    variantManifestRevision: manifest.revision,
  });
}

/** Owner-safe wire view: the object key and the revocation marker never leave the module. */
export function toAssetView(asset: MediaAsset): DeepReadonly<MediaAssetV1> {
  const { objectKeyHandle, revocationEpoch, restrictionDecisionRef, ...view } = asset;
  void objectKeyHandle;
  void revocationEpoch;
  void restrictionDecisionRef;
  return deepFreeze(view);
}

/**
 * Delivery is disabled first and wins over any late result. Only assets that
 * reached a settled state are deleted here; in-flight ones are refused.
 */
export function beginDeletion(asset: MediaAsset, nowUtc: UtcInstant): MediaAsset {
  const next = advance(asset, ['deleting'], nowUtc, {
    deliveryDisabled: true,
    revocationEpoch: revocationEpochOf(asset) + 1,
  });
  // The hold has done its job: the tombstone replaces it.
  const { deletionHold, ...rest } = next;
  void deletionHold;
  return deepFreeze(rest);
}

/**
 * Aborting or expiring an upload: with the object store confirming that no
 * object exists it is deleted at once, otherwise it goes through `deleting`
 * until cleanup is confirmed (BCK-14 v0.4 §34.3).
 */
export function abortUpload(
  asset: MediaAsset,
  objectAbsent: boolean,
  nowUtc: UtcInstant,
): MediaAsset {
  if (asset.lifecycle !== 'reserved' && asset.lifecycle !== 'uploading')
    throw new MediaDomainRefusal('invalid_state');
  const revocationEpoch = revocationEpochOf(asset) + 1;
  return objectAbsent
    ? advance(asset, ['deleted'], nowUtc, {
        deliveryDisabled: true,
        deletedAtUtc: nowUtc,
        revocationEpoch,
      })
    : advance(asset, ['deleting'], nowUtc, { deliveryDisabled: true, revocationEpoch });
}

/** Cleanup confirmed: `deleting` -> `deleted`; derived metadata is dropped. */
export function finishDeletion(asset: MediaAsset, nowUtc: UtcInstant): MediaAsset {
  const next = advance(asset, ['deleted'], nowUtc, { deletedAtUtc: nowUtc, variantRefs: [] });
  // The tombstone keeps identity and times only: no derived metadata and no
  // content hash of the source stay behind.
  const { variantManifestRevision, sourceGenerationRef, ...rest } = next;
  void variantManifestRevision;
  void sourceGenerationRef;
  return deepFreeze(rest);
}

/** A deletion hold as stored: who holds it and until when. */
export interface DeletionHold {
  readonly holdId: string;
  readonly expiresAtUtc: UtcInstant;
}

export function isHoldExpired(hold: DeletionHold, nowUtc: UtcInstant): boolean {
  return Date.parse(nowUtc) >= Date.parse(hold.expiresAtUtc);
}

/** The hold is still valid and belongs to exactly this holder. */
export function holdOwnedBy(asset: MediaAsset, holdId: string, nowUtc: UtcInstant): boolean {
  return asset.deletionHold?.holdId === holdId && !isHoldExpired(asset.deletionHold, nowUtc);
}

/** Delivery is disabled while an authoritative restriction or a deletion hold is set. */
function withFlags(
  asset: MediaAsset,
  flags: {
    readonly restricted: boolean;
    readonly hold: DeletionHold | undefined;
    /** Defaults to the stored decision while restricted, none once lifted. */
    readonly decisionRef?: string;
    readonly revocationEpoch?: number;
  },
  nowUtc: UtcInstant,
): MediaAsset {
  const {
    restricted: _restricted,
    deletionHold: _hold,
    restrictionDecisionRef: _decision,
    revocationEpoch: _epoch,
    ...rest
  } = asset;
  void _restricted;
  void _hold;
  const decisionRef = flags.restricted ? (flags.decisionRef ?? _decision) : undefined;
  const revocationEpoch = flags.revocationEpoch ?? _epoch;
  return deepFreeze({
    ...rest,
    ...(flags.restricted ? { restricted: true } : {}),
    ...(decisionRef === undefined ? {} : { restrictionDecisionRef: decisionRef }),
    ...(flags.hold === undefined ? {} : { deletionHold: flags.hold }),
    ...(revocationEpoch === undefined ? {} : { revocationEpoch }),
    deliveryDisabled: flags.restricted || flags.hold !== undefined,
    revision: asset.revision + 1,
    updatedAtUtc: nowUtc,
  });
}

/** A verified restriction instruction: a new decision, or the restore of one. */
export type RestrictionInstruction =
  | { readonly restricted: true; readonly decisionRef: string }
  | { readonly restricted: false; readonly restoresDecisionRef: string | undefined };

/**
 * The authoritative restriction changes its own flag only; it never changes the
 * lifecycle, never touches a deletion hold and never restores publicity. Every
 * new restriction decision raises the revocation epoch (D2 §3), which lifting
 * never lowers; a newer decision replaces an older one, and only the restore of
 * exactly the active decision lifts it.
 */
export function withRestriction(
  asset: MediaAsset,
  instruction: RestrictionInstruction,
  nowUtc: UtcInstant,
): MediaAsset {
  if (asset.lifecycle === 'deleting' || asset.lifecycle === 'deleted')
    throw new MediaDomainRefusal('invalid_state');
  if (instruction.restricted) {
    if (asset.restricted === true && asset.restrictionDecisionRef === instruction.decisionRef)
      return asset;
    return withFlags(
      asset,
      {
        restricted: true,
        hold: asset.deletionHold,
        decisionRef: instruction.decisionRef,
        revocationEpoch: revocationEpochOf(asset) + 1,
      },
      nowUtc,
    );
  }
  if (asset.restricted !== true) return asset;
  // A restore of an older, foreign or unnamed decision is stale: the active one stays.
  if (
    instruction.restoresDecisionRef === undefined ||
    asset.restrictionDecisionRef !== instruction.restoresDecisionRef
  )
    throw new MediaDomainRefusal('stale_revision');
  return withFlags(asset, { restricted: false, hold: asset.deletionHold }, nowUtc);
}

/**
 * The temporary hold a deletion places while the owning domain is asked. It is a
 * separate flag from the restriction and it is fenced: a hold still valid for
 * someone else refuses (the caller starts over), an expired one may be taken over.
 */
export function placeDeletionHold(
  asset: MediaAsset,
  hold: DeletionHold,
  nowUtc: UtcInstant,
): MediaAsset {
  if (asset.deletionHold !== undefined && !isHoldExpired(asset.deletionHold, nowUtc))
    throw new MediaDomainRefusal('revision_conflict');
  return withFlags(asset, { restricted: asset.restricted === true, hold }, nowUtc);
}

/**
 * Releases the hold of exactly this holder while it is still valid. A holder whose
 * lease ran out, or whose hold was taken over or already released, changes nothing.
 */
export function releaseDeletionHold(
  asset: MediaAsset,
  holdId: string,
  nowUtc: UtcInstant,
): MediaAsset {
  if (!holdOwnedBy(asset, holdId, nowUtc)) return asset;
  return withFlags(asset, { restricted: asset.restricted === true, hold: undefined }, nowUtc);
}

/** Recovery of a hold whose holder never came back: only an expired hold is released. */
export function releaseExpiredDeletionHold(asset: MediaAsset, nowUtc: UtcInstant): MediaAsset {
  if (asset.deletionHold === undefined || !isHoldExpired(asset.deletionHold, nowUtc)) return asset;
  return withFlags(asset, { restricted: asset.restricted === true, hold: undefined }, nowUtc);
}

/** Starts or clears the orphan grace clock; unchanged state is not a new revision. */
export function withOrphanSince(
  asset: MediaAsset,
  since: UtcInstant | null,
  nowUtc: UtcInstant,
): MediaAsset {
  if (since !== null && asset.orphanSinceUtc !== undefined) return asset;
  if (since === null && asset.orphanSinceUtc === undefined) return asset;
  const { orphanSinceUtc, ...rest } = asset;
  void orphanSinceUtc;
  return deepFreeze({
    ...rest,
    ...(since === null ? {} : { orphanSinceUtc: since }),
    revision: asset.revision + 1,
    updatedAtUtc: nowUtc,
  });
}
