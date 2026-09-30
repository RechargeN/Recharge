import type { MediaVariantRefV1 } from '../../../contracts/media_v1.js';
import { canonicalJson, sha256Hex, type MediaAsset } from './media_asset.js';

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

/**
 * Immutable variant history: an earlier generation is never overwritten, and a
 * new set may not reuse any generation an earlier set already holds.
 */
export function variantsPreserveHistory(
  previous: readonly MediaVariantRefV1[],
  next: readonly MediaVariantRefV1[],
): boolean {
  if (previous.length === 0) return true;
  const used = new Set(previous.map((item) => item.providerGeneration));
  return next.every((item) => !used.has(item.providerGeneration));
}

/**
 * Metadata other domains may read: identity, profile, format and dimensions.
 * Provider generations, hashes and byte lengths stay inside Media.
 */
export interface VariantMetadata {
  readonly variantId: string;
  readonly profile: string;
  readonly format: string;
  readonly width?: number;
  readonly height?: number;
  readonly durationMs?: number;
}

export function toVariantMetadata(asset: MediaAsset): readonly VariantMetadata[] {
  if (asset.lifecycle !== 'ready' || asset.deliveryDisabled) return [];
  if (asset.visibilityClass !== 'publicDerived') return [];
  return asset.variantRefs.map((variant) => ({
    variantId: variant.variantId,
    profile: variant.profile,
    format: variant.format,
    ...(variant.width === undefined ? {} : { width: variant.width }),
    ...(variant.height === undefined ? {} : { height: variant.height }),
    ...(variant.durationMs === undefined ? {} : { durationMs: variant.durationMs }),
  }));
}
