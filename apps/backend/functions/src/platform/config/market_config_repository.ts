import type { EnvironmentId } from '../../config/environment.js';
import type { MarketId } from '../../modules/reference_data/domain/identifiers.js';
import type { MarketConfigRevision } from '../../modules/reference_data/domain/market_config.js';
import { referenceDataCapabilityId } from '../../modules/reference_data/domain/market_config.js';
import type {
  MarketConfigRepositoryPort,
  ReferenceActivationPointer,
  ReferencePointerSwapResult,
} from '../../modules/reference_data/domain/repositories.js';
import { deepFreeze, type DeepReadonly } from '../../shared/immutable.js';

export const marketConfigRevisionCollection = 'referenceMarketConfigRevisions';
export const referenceActivationPointerCollection = 'referenceActivationPointers';

export type MarketConfigPointer = ReferenceActivationPointer;
export type MarketPointerSwapResult = ReferencePointerSwapResult;
export type MarketConfigRepository = MarketConfigRepositoryPort;

export class InMemoryMarketConfigRepository implements MarketConfigRepositoryPort {
  readonly #configs = new Map<string, DeepReadonly<MarketConfigRevision>>();
  readonly #pointers = new Map<string, DeepReadonly<ReferenceActivationPointer>>();

  publish(config: MarketConfigRevision): Promise<void> {
    if (config.status !== 'disabled') throw new TypeError('r1_market_config_must_be_disabled');
    const existing = this.#configs.get(config.revisionId);
    const frozen = deepFreeze({
      ...config,
      supportedLocales: [...config.supportedLocales],
      fallbackLocaleOrder: [...config.fallbackLocaleOrder],
      languageFallbacks: { ...config.languageFallbacks },
      currencyCodes: [...config.currencyCodes],
      allowedIanaZones: [...config.allowedIanaZones],
      sourceRecordIds: [...config.sourceRecordIds],
      capabilityMatrix: config.capabilityMatrix.map((entry) => ({ ...entry })),
      policyPointers: { ...config.policyPointers },
    });
    if (existing !== undefined && JSON.stringify(existing) !== JSON.stringify(frozen)) {
      throw new TypeError('immutable_market_config_conflict');
    }
    this.#configs.set(config.revisionId, existing ?? frozen);
    return Promise.resolve();
  }

  getById(revisionId: string): Promise<DeepReadonly<MarketConfigRevision> | null> {
    return Promise.resolve(this.#configs.get(revisionId) ?? null);
  }

  getActivePointer(key: string): Promise<DeepReadonly<MarketConfigPointer> | null> {
    return Promise.resolve(this.#pointers.get(key) ?? null);
  }

  swapActivePointer(
    key: string,
    revisionId: string,
    expectedPointerRevision: number,
  ): Promise<MarketPointerSwapResult> {
    assertPointerRevision(expectedPointerRevision);
    const target = this.#configs.get(revisionId);
    if (target === undefined || marketConfigKey(target.environmentId, target.marketId) !== key) {
      return Promise.resolve({ swapped: false, reason: 'revision_not_found' });
    }
    const current = this.#pointers.get(key);
    if ((current?.pointerRevision ?? 0) !== expectedPointerRevision) {
      return Promise.resolve({ swapped: false, reason: 'revision_conflict' });
    }
    const pointer = deepFreeze({
      key,
      activeRevisionId: revisionId,
      pointerRevision: expectedPointerRevision + 1,
    });
    this.#pointers.set(key, pointer);
    return Promise.resolve({ swapped: true, pointer });
  }
}

function assertPointerRevision(value: number): void {
  if (!Number.isSafeInteger(value) || value < 0) throw new TypeError('pointer_revision_invalid');
}

export function marketConfigKey(environmentId: EnvironmentId, marketId: MarketId): string {
  return `${environmentId}:${marketId}:${referenceDataCapabilityId}`;
}
