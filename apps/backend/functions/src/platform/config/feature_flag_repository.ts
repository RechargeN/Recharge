import { environmentIds, type EnvironmentId } from '../../config/environment.js';
import type { FeatureFlagRevision } from '../../config/feature_flags.js';
import { marketIds, type MarketId } from '../../config/market_capability.js';
import { deepFreeze, type DeepReadonly } from '../../shared/immutable.js';

export const featureFlagRevisionCollection = 'platformFeatureFlagRevisions';

export function featureFlagKey(
  environmentId: EnvironmentId,
  marketId: MarketId,
  capabilityId: string,
): string {
  return `${environmentId}:${marketId}:${capabilityId}`;
}

export interface FeatureFlagPointer {
  readonly key: string;
  readonly activeRevision: number;
  readonly pointerRevision: number;
}

export type PointerSwapResult =
  | { readonly swapped: true; readonly pointer: DeepReadonly<FeatureFlagPointer> }
  | { readonly swapped: false; readonly reason: 'revision_not_found' | 'revision_conflict' };

export interface FeatureFlagRepository {
  publish(revision: FeatureFlagRevision): Promise<void>;
  getRevision(
    environmentId: EnvironmentId,
    marketId: MarketId,
    capabilityId: string,
    revision: number,
  ): Promise<DeepReadonly<FeatureFlagRevision> | null>;
  getActivePointer(key: string): Promise<DeepReadonly<FeatureFlagPointer> | null>;
  swapActivePointer(
    key: string,
    activeRevision: number,
    expectedPointerRevision: number,
  ): Promise<PointerSwapResult>;
}

export class InMemoryFeatureFlagRepository implements FeatureFlagRepository {
  readonly #revisions = new Map<string, DeepReadonly<FeatureFlagRevision>>();
  readonly #pointers = new Map<string, DeepReadonly<FeatureFlagPointer>>();

  publish(revision: FeatureFlagRevision): Promise<void> {
    if (revision.enabled !== false) throw new TypeError('r1_feature_flag_must_be_disabled');
    const key = revisionStorageKey(
      revision.environmentId,
      revision.marketId,
      revision.capabilityId,
      revision.revision,
    );
    const existing = this.#revisions.get(key);
    const frozen = deepFreeze({ ...revision });
    if (existing !== undefined && JSON.stringify(existing) !== JSON.stringify(frozen)) {
      throw new TypeError('immutable_feature_flag_revision_conflict');
    }
    this.#revisions.set(key, existing ?? frozen);
    return Promise.resolve();
  }

  getRevision(
    environmentId: EnvironmentId,
    marketId: MarketId,
    capabilityId: string,
    revision: number,
  ): Promise<DeepReadonly<FeatureFlagRevision> | null> {
    return Promise.resolve(
      this.#revisions.get(revisionStorageKey(environmentId, marketId, capabilityId, revision)) ??
        null,
    );
  }

  getActivePointer(key: string): Promise<DeepReadonly<FeatureFlagPointer> | null> {
    return Promise.resolve(this.#pointers.get(key) ?? null);
  }

  swapActivePointer(
    key: string,
    activeRevision: number,
    expectedPointerRevision: number,
  ): Promise<PointerSwapResult> {
    assertPointerRevision(expectedPointerRevision);
    assertPointerRevision(activeRevision);
    const parsed = parseFlagKey(key);
    if (
      !this.#revisions.has(
        revisionStorageKey(
          parsed.environmentId,
          parsed.marketId,
          parsed.capabilityId,
          activeRevision,
        ),
      )
    ) {
      return Promise.resolve({ swapped: false, reason: 'revision_not_found' });
    }
    const current = this.#pointers.get(key);
    if ((current?.pointerRevision ?? 0) !== expectedPointerRevision) {
      return Promise.resolve({ swapped: false, reason: 'revision_conflict' });
    }
    const pointer = deepFreeze({
      key,
      activeRevision,
      pointerRevision: expectedPointerRevision + 1,
    });
    this.#pointers.set(key, pointer);
    return Promise.resolve({ swapped: true, pointer });
  }
}

function revisionStorageKey(
  environmentId: EnvironmentId,
  marketId: MarketId,
  capabilityId: string,
  revision: number,
): string {
  return `${environmentId}:${marketId}:${capabilityId}:${revision}`;
}

function parseFlagKey(key: string): {
  environmentId: EnvironmentId;
  marketId: MarketId;
  capabilityId: string;
} {
  const parts = key.split(':');
  if (parts.length !== 3) throw new TypeError('feature_flag_pointer_key_invalid');
  if (
    !environmentIds.includes(parts[0] as EnvironmentId) ||
    !marketIds.includes(parts[1] as MarketId) ||
    !/^[a-z][a-z0-9._-]{0,95}$/.test(parts[2] ?? '')
  ) {
    throw new TypeError('feature_flag_pointer_key_invalid');
  }
  return {
    environmentId: parts[0] as EnvironmentId,
    marketId: parts[1] as MarketId,
    capabilityId: parts[2] as string,
  };
}

function assertPointerRevision(value: number): void {
  if (!Number.isSafeInteger(value) || value < 0) throw new TypeError('pointer_revision_invalid');
}
