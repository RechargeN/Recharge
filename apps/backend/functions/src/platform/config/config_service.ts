import type { FeatureFlagRevision } from '../../config/feature_flags.js';
import {
  featureFlagKey,
  type FeatureFlagRepository,
  type PointerSwapResult,
} from './feature_flag_repository.js';

export class ConfigService {
  constructor(private readonly featureFlags: FeatureFlagRepository) {}

  async publishFeatureFlag(revision: FeatureFlagRevision): Promise<void> {
    if (revision.enabled !== false) throw new TypeError('r1_feature_flag_must_be_disabled');
    await this.featureFlags.publish(revision);
  }

  async activateFeatureFlag(
    revision: FeatureFlagRevision,
    expectedPointerRevision: number,
  ): Promise<PointerSwapResult> {
    if (revision.enabled !== false) throw new TypeError('r1_feature_flag_must_be_disabled');
    return this.featureFlags.swapActivePointer(
      featureFlagKey(revision.environmentId, revision.marketId, revision.capabilityId),
      revision.revision,
      expectedPointerRevision,
    );
  }
}
