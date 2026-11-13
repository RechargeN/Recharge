import type { MarketConfigRevision } from '../domain/market_config.js';
import { isCompatibleMarketConfigRollback } from '../domain/market_config.js';
import type {
  MarketConfigRepositoryPort,
  ReferencePointerSwapResult,
} from '../domain/repositories.js';

export async function rollbackMarketConfig(input: {
  readonly repository: MarketConfigRepositoryPort;
  readonly current: MarketConfigRevision;
  readonly target: MarketConfigRevision;
  readonly pointerKey: string;
  readonly expectedPointerRevision: number;
}): Promise<
  ReferencePointerSwapResult | { readonly swapped: false; readonly reason: 'incompatible_rollback' }
> {
  if (!isCompatibleMarketConfigRollback(input.current, input.target)) {
    return { swapped: false, reason: 'incompatible_rollback' };
  }
  return input.repository.swapActivePointer(
    input.pointerKey,
    input.target.revisionId,
    input.expectedPointerRevision,
  );
}
