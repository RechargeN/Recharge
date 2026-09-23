import type { DeepReadonly } from '../../../shared/immutable.js';
import type { MarketConfigRevision } from './market_config.js';

export interface ReferenceActivationPointer {
  readonly key: string;
  readonly activeRevisionId: string;
  readonly pointerRevision: number;
}

export type ReferencePointerSwapResult =
  | { readonly swapped: true; readonly pointer: DeepReadonly<ReferenceActivationPointer> }
  | { readonly swapped: false; readonly reason: 'revision_not_found' | 'revision_conflict' };

export interface MarketConfigRepositoryPort {
  publish(config: MarketConfigRevision): Promise<void>;
  getById(revisionId: string): Promise<DeepReadonly<MarketConfigRevision> | null>;
  getActivePointer(key: string): Promise<DeepReadonly<ReferenceActivationPointer> | null>;
  swapActivePointer(
    key: string,
    revisionId: string,
    expectedPointerRevision: number,
  ): Promise<ReferencePointerSwapResult>;
}
