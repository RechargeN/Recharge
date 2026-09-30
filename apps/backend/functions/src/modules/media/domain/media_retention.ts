import type { UtcInstant } from '../../../shared/utc_instant.js';
import { MediaDomainRefusal } from './failures.js';
import type { MediaAsset } from './media_asset.js';
import { isSessionExpired, type UploadSession } from './upload_session.js';

/** Data classes with their own retention (BCK-14-AC-73); no class inherits another's period. */
export const mediaDataClasses = [
  'sourceBytes',
  'derivedVariants',
  'scanFindings',
  'auditRecords',
  'deletionReceipts',
] as const;
export type MediaDataClass = (typeof mediaDataClasses)[number];

/**
 * Accepted retention policy. No period is invented by the platform: tests use a
 * synthetic, explicitly test-only policy and a working configuration without an
 * accepted one is `policy_unavailable` (BCK-14 v0.4 §34.5).
 */
export interface MediaRetentionPolicy {
  readonly revision: string;
  /** Grace after the last owning-domain reference disappeared, per data class. */
  readonly orphanGraceSeconds: number;
  readonly quarantinedRetentionSeconds: number;
  readonly blockedRetentionSeconds: number;
  /** Retention of the deletion receipt itself, separate from the bytes it covers. */
  readonly deletionReceiptRetentionSeconds: number;
}

export function requireRetentionPolicy(
  policy: MediaRetentionPolicy | undefined,
): MediaRetentionPolicy {
  if (policy === undefined) throw new MediaDomainRefusal('policy_unavailable');
  return policy;
}

export type OrphanDecision =
  | { readonly action: 'keep' }
  | { readonly action: 'mark' }
  | { readonly action: 'unmark' }
  | { readonly action: 'resume_delete' }
  | { readonly action: 'delete'; readonly reason: 'orphan_cleanup' | 'expired_upload' };

export interface OrphanInput {
  readonly asset: MediaAsset;
  readonly session: UploadSession | null;
  readonly referenced: boolean;
  readonly policy: MediaRetentionPolicy;
  readonly nowUtc: UtcInstant;
}

/**
 * Keep, mark, unmark or delete. In-flight assets are never touched, an
 * unfinished upload past its session is cleaned up, and an unreferenced asset is
 * deleted only after the grace of its state has passed since it was marked.
 */
export function decideOrphan(input: OrphanInput): OrphanDecision {
  const { asset, session, referenced, policy, nowUtc } = input;
  if (asset.lifecycle === 'deleted') return { action: 'keep' };
  if (asset.lifecycle === 'deleting') return { action: 'resume_delete' };
  if (asset.lifecycle === 'reserved' || asset.lifecycle === 'uploading')
    return session === null || session.state !== 'open' || isSessionExpired(session, nowUtc)
      ? { action: 'delete', reason: 'expired_upload' }
      : { action: 'keep' };
  if (
    asset.lifecycle === 'uploaded' ||
    asset.lifecycle === 'validating' ||
    asset.lifecycle === 'processing'
  )
    return { action: 'keep' };
  if (referenced)
    return asset.orphanSinceUtc === undefined ? { action: 'keep' } : { action: 'unmark' };
  if (asset.orphanSinceUtc === undefined) return { action: 'mark' };
  const graceSeconds =
    asset.lifecycle === 'quarantined'
      ? policy.quarantinedRetentionSeconds
      : asset.lifecycle === 'blocked'
        ? policy.blockedRetentionSeconds
        : policy.orphanGraceSeconds;
  return Date.parse(nowUtc) - Date.parse(asset.orphanSinceUtc) >= graceSeconds * 1000
    ? { action: 'delete', reason: 'orphan_cleanup' }
    : { action: 'keep' };
}
