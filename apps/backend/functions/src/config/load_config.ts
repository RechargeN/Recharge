import type { EnvironmentConfig } from './environment.js';
import type { FeatureFlagRevision } from './feature_flags.js';
import type { MarketConfigRevision } from '../modules/reference_data/domain/market_config.js';
import type { RegionPolicy } from './region_policy.js';
import type { SecretReference } from './secret_refs.js';
import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';

export interface PlatformConfigBundle {
  readonly environment: EnvironmentConfig;
  readonly regionPolicy: RegionPolicy;
  readonly marketCapabilities: readonly MarketConfigRevision[];
  readonly featureFlags: readonly FeatureFlagRevision[];
  readonly secretReferences: readonly SecretReference[];
}

export function loadPlatformConfig(
  bundle: PlatformConfigBundle,
): DeepReadonly<PlatformConfigBundle> {
  const environmentId = bundle.environment.environmentId;
  if (
    bundle.environment.cloudAllowed !== false ||
    bundle.regionPolicy.activationState !== 'disabled'
  ) {
    throw new TypeError('r1_cloud_or_region_activation_forbidden');
  }
  if (bundle.regionPolicy.environmentId !== environmentId) {
    throw new TypeError('environment_region_mismatch');
  }
  if (
    bundle.marketCapabilities.some(
      (config) => config.environmentId !== environmentId || config.status !== 'disabled',
    ) ||
    bundle.featureFlags.some(
      (flag) => flag.environmentId !== environmentId || flag.enabled !== false,
    ) ||
    bundle.secretReferences.some(
      (reference) =>
        reference.environmentId !== environmentId || reference.bindingState !== 'unbound',
    )
  ) {
    throw new TypeError('r1_config_must_remain_disabled_and_unbound');
  }
  return deepFreeze({
    environment: bundle.environment,
    regionPolicy: bundle.regionPolicy,
    marketCapabilities: [...bundle.marketCapabilities],
    featureFlags: [...bundle.featureFlags],
    secretReferences: [...bundle.secretReferences],
  });
}
