import type { MarketConfigRevision } from '../domain/market_config.js';
import {
  isCompatibleMarketConfigRollback,
  referenceDataCapabilityId,
} from '../domain/market_config.js';
import type { MarketId, ReferenceEnvironmentId } from '../domain/identifiers.js';
import type {
  MarketConfigRepositoryPort,
  ReferencePointerSwapResult,
} from '../domain/repositories.js';

export class ReferenceDataService {
  constructor(private readonly marketConfigs: MarketConfigRepositoryPort) {}

  async publishMarketConfig(config: MarketConfigRevision): Promise<void> {
    assertLocalFoundationConfig(config);
    await this.marketConfigs.publish(config);
  }

  async activateMarketConfig(
    config: MarketConfigRevision,
    expectedPointerRevision: number,
  ): Promise<ReferencePointerSwapResult> {
    assertLocalFoundationConfig(config);
    return this.marketConfigs.swapActivePointer(
      referenceDataPointerKey(config.environmentId, config.marketId),
      config.revisionId,
      expectedPointerRevision,
    );
  }

  async rollbackMarketConfig(
    current: MarketConfigRevision,
    target: MarketConfigRevision,
    expectedPointerRevision: number,
  ): Promise<
    | ReferencePointerSwapResult
    | { readonly swapped: false; readonly reason: 'incompatible_rollback' }
  > {
    if (!isCompatibleMarketConfigRollback(current, target))
      return { swapped: false, reason: 'incompatible_rollback' };
    return this.activateMarketConfig(target, expectedPointerRevision);
  }
}

export function referenceDataPointerKey(
  environmentId: ReferenceEnvironmentId,
  marketId: MarketId,
): string {
  return `${environmentId}:${marketId}:${referenceDataCapabilityId}`;
}

function assertLocalFoundationConfig(config: MarketConfigRevision): void {
  if (config.schemaVersion !== 1) throw new TypeError('reference_data_schema_unsupported');
  if (config.status !== 'disabled') throw new TypeError('reference_data_market_must_be_disabled');
}
