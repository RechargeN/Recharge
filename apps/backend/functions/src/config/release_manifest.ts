import type { EnvironmentId } from './environment.js';
import type { MarketId } from './market_capability.js';
import { parseEntityId, type EntityId } from '../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../shared/utc_instant.js';

export interface ReleaseManifest {
  readonly schemaVersion: 1;
  readonly manifestId: EntityId;
  readonly revision: number;
  readonly environmentId: EnvironmentId;
  readonly marketId: MarketId;
  readonly capabilityId: string;
  readonly status: 'disabled';
  readonly artifactDigest: `sha256:${string}`;
  readonly apiSchemaRevision: string;
  readonly marketConfigRevision: string;
  readonly securityPrivacyEvidenceRevision: string;
  readonly retentionDsrRevision: string;
  readonly residencyTransferRevision: string;
  readonly observabilityPolicyRevision: string;
  readonly rollbackTargetManifestId: EntityId | null;
  readonly createdAtUtc: UtcInstant;
  readonly effectiveAtUtc: UtcInstant;
  readonly approvedBy: readonly string[];
}

export function createDisabledReleaseManifest(
  input: Omit<
    ReleaseManifest,
    | 'schemaVersion'
    | 'manifestId'
    | 'status'
    | 'rollbackTargetManifestId'
    | 'createdAtUtc'
    | 'effectiveAtUtc'
  > & {
    readonly manifestId: string;
    readonly rollbackTargetManifestId: string | null;
    readonly createdAtUtc: string;
    readonly effectiveAtUtc: string;
  },
): DeepReadonly<ReleaseManifest> {
  if (!Number.isSafeInteger(input.revision) || input.revision < 0) {
    throw new TypeError('release_revision_invalid');
  }
  if (!/^sha256:[0-9a-f]{64}$/.test(input.artifactDigest)) {
    throw new TypeError('artifact_digest_invalid');
  }
  return deepFreeze({
    ...input,
    schemaVersion: 1,
    manifestId: parseEntityId(input.manifestId),
    status: 'disabled',
    rollbackTargetManifestId:
      input.rollbackTargetManifestId === null
        ? null
        : parseEntityId(input.rollbackTargetManifestId),
    createdAtUtc: parseUtcInstant(input.createdAtUtc),
    effectiveAtUtc: parseUtcInstant(input.effectiveAtUtc),
    approvedBy: [...new Set(input.approvedBy)],
  });
}

export function sameReleaseScope(left: ReleaseManifest, right: ReleaseManifest): boolean {
  return (
    left.environmentId === right.environmentId &&
    left.marketId === right.marketId &&
    left.capabilityId === right.capabilityId
  );
}

export function isReleaseCompatible(current: ReleaseManifest, target: ReleaseManifest): boolean {
  return (
    sameReleaseScope(current, target) &&
    current.apiSchemaRevision === target.apiSchemaRevision &&
    current.securityPrivacyEvidenceRevision === target.securityPrivacyEvidenceRevision &&
    target.status === 'disabled'
  );
}
