import type { EnvironmentId } from './environment.js';
import type { MarketId } from './market_capability.js';
import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../shared/utc_instant.js';

export interface FeatureFlagRevision {
  readonly schemaVersion: 1;
  readonly revision: number;
  readonly environmentId: EnvironmentId;
  readonly marketId: MarketId;
  readonly capabilityId: string;
  readonly enabled: boolean;
  readonly createdAtUtc: UtcInstant;
}

export function createDisabledFeatureFlag(input: {
  readonly revision: number;
  readonly environmentId: EnvironmentId;
  readonly marketId: MarketId;
  readonly capabilityId: string;
  readonly createdAtUtc: string;
}): DeepReadonly<FeatureFlagRevision> {
  return createFeatureFlag({ ...input, enabled: false });
}

export function createFeatureFlag(input: {
  readonly revision: number;
  readonly environmentId: EnvironmentId;
  readonly marketId: MarketId;
  readonly capabilityId: string;
  readonly enabled: boolean;
  readonly createdAtUtc: string;
}): DeepReadonly<FeatureFlagRevision> {
  if (!Number.isSafeInteger(input.revision) || input.revision < 0) {
    throw new TypeError('feature_flag_revision_invalid');
  }
  if (!/^[a-z][a-z0-9._-]{0,95}$/.test(input.capabilityId)) {
    throw new TypeError('feature_flag_capability_invalid');
  }
  return deepFreeze({
    schemaVersion: 1,
    revision: input.revision,
    environmentId: input.environmentId,
    marketId: input.marketId,
    capabilityId: input.capabilityId,
    enabled: input.enabled,
    createdAtUtc: parseUtcInstant(input.createdAtUtc),
  });
}

export function isFeatureEnabled(revision: FeatureFlagRevision | undefined): boolean {
  return revision?.enabled === true;
}
