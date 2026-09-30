import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { canonicalJson, sha256Hex, type MediaAsset } from './media_asset.js';

/** Generation-pinned reference an owning domain stores in its immutable record. */
export interface MediaAttachment {
  readonly assetId: EntityId;
  readonly sourceGeneration: string;
  readonly variantManifestRevision: string;
  readonly purpose: 'contentMedia';
}

export type NotReadyReason =
  | 'asset_unknown'
  | 'foreign_binding'
  | 'stale_generation'
  | 'deleted'
  | 'restricted'
  | 'not_ready'
  | 'policy_unavailable';

/**
 * Lowercase hex SHA-256 of the canonical JSON of the attachments sorted by
 * `assetId`. A hash alone cannot restore references, which is why the owning
 * domain stores the attachments themselves (BCK-07 v0.11 §37.1).
 */
export function attachmentsRevision(attachments: readonly MediaAttachment[]): string {
  const sorted = [...attachments].sort((left, right) => left.assetId.localeCompare(right.assetId));
  return sha256Hex(canonicalJson(sorted));
}

export interface AttachmentExpectation {
  readonly contentId: string;
  readonly publisherRef: PublisherRefV1;
  readonly marketId: string;
}

export type AttachmentCheck =
  | { readonly ok: true; readonly attachment: MediaAttachment }
  | { readonly ok: false; readonly reason: NotReadyReason };

/**
 * Whether one asset is attachable to exactly this entity, Publisher and market
 * right now, and (for rollback) still matches the pinned reference. Binding data
 * comes from Media's own records, never from the caller.
 */
export function checkAttachment(
  asset: MediaAsset | null,
  expected: AttachmentExpectation,
  pinned?: MediaAttachment,
): AttachmentCheck {
  if (asset === null) return { ok: false, reason: 'asset_unknown' };
  const binding = asset.entityBinding;
  if (
    binding?.domain !== 'content' ||
    binding.entityId !== expected.contentId ||
    binding.purpose !== 'contentMedia' ||
    asset.publisherRef?.type !== expected.publisherRef.type ||
    asset.publisherRef.id !== expected.publisherRef.id ||
    asset.marketId !== expected.marketId
  )
    return { ok: false, reason: 'foreign_binding' };
  if (asset.lifecycle === 'deleting' || asset.lifecycle === 'deleted')
    return { ok: false, reason: 'deleted' };
  if (asset.deliveryDisabled) return { ok: false, reason: 'restricted' };
  // Public Content only ever references derived, public-class assets: a private or
  // protected original never becomes part of a public revision.
  if (asset.visibilityClass !== 'publicDerived') return { ok: false, reason: 'restricted' };
  if (asset.lifecycle !== 'ready') return { ok: false, reason: 'not_ready' };
  const generation = asset.sourceGenerationRef?.providerGeneration;
  const manifest = asset.variantManifestRevision;
  if (generation === undefined || manifest === undefined) return { ok: false, reason: 'not_ready' };
  if (
    pinned !== undefined &&
    (pinned.sourceGeneration !== generation || pinned.variantManifestRevision !== manifest)
  )
    return { ok: false, reason: 'stale_generation' };
  return {
    ok: true,
    attachment: {
      assetId: asset.assetId,
      sourceGeneration: generation,
      variantManifestRevision: manifest,
      purpose: 'contentMedia',
    },
  };
}
