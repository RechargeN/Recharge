import type { ContentEffectV1 } from '../../../../contracts/content_v1.js';
import type { AttachedMediaState } from '../../domain/publication_pointer.js';
import type { FeedPosition } from '../../domain/repositories.js';

/**
 * Media's answer about attached assets now (D2 §5.2). Media implements it from
 * its own records; Content never imports the Media module.
 */
export interface MediaAvailabilityPort {
  availability(assetIds: readonly string[]): Promise<readonly AttachedMediaState[]>;
}

/** A committed Media fact as Media stored it: ids and revisions only. */
export interface MediaFact {
  readonly effectId: string;
  readonly type: string;
  readonly assetId: string;
  readonly assetRevision: number;
  readonly occurredAtUtc: string;
}

/** Committed Media facts in `(occurredAtUtc, effectId)` order, strictly after `after`. */
export interface MediaFactSource {
  effectsAfter(after: FeedPosition | null, limit: number): Promise<readonly MediaFact[]>;
}

/** Committed Content facts in `(occurredAtUtc, effectId)` order, strictly after `after`. */
export interface ContentFactSource {
  effectsAfter(after: FeedPosition | null, limit: number): Promise<readonly ContentEffectV1[]>;
}
