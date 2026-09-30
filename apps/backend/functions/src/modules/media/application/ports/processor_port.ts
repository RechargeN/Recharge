import type { MediaFamily, MediaVariantRefV1 } from '../../../../contracts/media_v1.js';

export interface ProcessRequest {
  readonly assetId: string;
  readonly objectKeyHandle: string;
  readonly family: MediaFamily;
  readonly sourceProviderGeneration: string;
  readonly sourceSha256: string;
  readonly policyRevision: string;
  readonly mandatoryVariantProfiles: readonly string[];
}

export type ProcessOutcome =
  | {
      readonly toolRevision: string;
      readonly result: 'succeeded';
      readonly variants: readonly MediaVariantRefV1[];
    }
  | { readonly toolRevision: string; readonly result: 'failed' | 'rejected' };

/**
 * Trusted processor producing immutable variants from a verified source. Only
 * its verified output can make an asset `ready`. The adapter in this slice is
 * `fake_processor`, which proves orchestration only.
 */
export interface ProcessorPort {
  process(request: ProcessRequest): Promise<ProcessOutcome>;
}
