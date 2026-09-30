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

/** Stored asset: the wire view plus the backend-selected object key handle. */
export type MediaAsset = DeepReadonly<MediaAssetV1> & { readonly objectKeyHandle: string };

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
  readonly deletedAtUtc?: UtcInstant;
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

export type VariantManifest =
  | {
      readonly ok: true;
      readonly revision: string;
      readonly variants: readonly MediaVariantRefV1[];
    }
  | { readonly ok: false };

/**
 * Verifies the processor output against the asset and the mandatory profiles and
 * derives the manifest revision. Reprocessing never reuses a generation: a
 * variant can never carry the source generation.
 */
export function verifyVariantManifest(
  asset: MediaAsset,
  variants: readonly MediaVariantRefV1[],
  mandatoryProfiles: readonly string[],
): VariantManifest {
  const source = asset.sourceGenerationRef;
  if (source === undefined || variants.length === 0) return { ok: false };
  const profiles = new Set<string>();
  for (const variant of variants) {
    if (profiles.has(variant.profile)) return { ok: false };
    profiles.add(variant.profile);
    if (variant.sourceProviderGeneration !== source.providerGeneration) return { ok: false };
    if (variant.providerGeneration === source.providerGeneration) return { ok: false };
    if (!/^[0-9a-f]{64}$/u.test(variant.sha256) || variant.byteLength < 1) return { ok: false };
  }
  for (const profile of mandatoryProfiles) if (!profiles.has(profile)) return { ok: false };
  const sorted = [...variants].sort((left, right) => left.profile.localeCompare(right.profile));
  return {
    ok: true,
    variants: sorted,
    revision: sha256Hex(
      canonicalJson({ algorithm: 'media_variant_manifest_v1', variants: sorted }),
    ),
  };
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

/** Owner-safe wire view: the backend object key never leaves the module. */
export function toAssetView(asset: MediaAsset): DeepReadonly<MediaAssetV1> {
  const { objectKeyHandle, ...view } = asset;
  void objectKeyHandle;
  return deepFreeze(view);
}
