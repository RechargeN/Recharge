import { ContentDomainRefusal } from './failures.js';
import { canonicalJson } from './published_revision.js';

/**
 * Local storage guards (BCK-07 v0.12 §38.4). They are synthetic engineering
 * bounds for the local repositories, not product limits: production values need
 * the cost and cardinality measurement required by §14.
 */
export interface ContentStorageLimits {
  readonly maxRevisionsPerContent: number;
  readonly maxSubmissionsPerContent: number;
  readonly maxDocumentBytes: number;
  readonly maxMediaAssetIds: number;
}

export const defaultContentStorageLimits: ContentStorageLimits = Object.freeze({
  maxRevisionsPerContent: 200,
  maxSubmissionsPerContent: 200,
  maxDocumentBytes: 900_000,
  maxMediaAssetIds: 100,
});

export function resolveStorageLimits(
  overrides: Partial<ContentStorageLimits> | undefined,
): ContentStorageLimits {
  return Object.freeze({ ...defaultContentStorageLimits, ...overrides });
}

/** Size of the whole persisted document: canonical UTF-8 JSON, outcomes and attachments included. */
export function documentBytes(value: unknown): number {
  return Buffer.byteLength(canonicalJson(value), 'utf8');
}

export function assertDocumentWithinLimit(value: unknown, limits: ContentStorageLimits): void {
  if (documentBytes(value) > limits.maxDocumentBytes)
    throw new ContentDomainRefusal('storage_limit_exceeded');
}

/** Refuses when adding one more record would exceed the per-Content history bound. */
export function assertRoomForHistory(currentCount: number, max: number): void {
  if (currentCount >= max) throw new ContentDomainRefusal('storage_limit_exceeded');
}

export function assertMediaIdsWithinLimit(count: number, limits: ContentStorageLimits): void {
  if (count > limits.maxMediaAssetIds) throw new ContentDomainRefusal('storage_limit_exceeded');
}
