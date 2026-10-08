import type { ContentFact, SourceRevision } from '../domain/catalog_item.js';
import type { FeedCheckpoint } from '../domain/repositories.js';

/** Current state of one Content object, as its owner reports it. */
export interface SourcePointer {
  readonly contentId: string;
  readonly revision: number;
  readonly currentPublishedRevisionId: string | null;
  readonly visibility: string;
}

/**
 * Read-only view of Content (BCK-07) through its owner's interface: committed
 * facts, current pointers and immutable published revisions. The Catalog never
 * writes Content and never reads its drafts.
 */
export interface ContentCatalogSource {
  /** Committed facts of every object in `(occurredAtUtc, effectId)` order. */
  effectsAfter(after: FeedCheckpoint | null, limit: number): Promise<readonly ContentFact[]>;
  /** Stored facts of one object in `(pointerRevision, effectId)` order. */
  effectsForContent(
    contentId: string,
    after: { readonly pointerRevision: number; readonly effectId: string } | null,
    limit: number,
  ): Promise<readonly ContentFact[]>;
  latestEffect(): Promise<FeedCheckpoint | null>;
  pointersPage(afterContentId: string | null, limit: number): Promise<readonly SourcePointer[]>;
  publishedRevision(publishedRevisionId: string): Promise<SourceRevision | null>;
  typeVisibilityPolicy(typeId: string): string | undefined;
}

/** Current reference revisions (market, taxonomy, localization) of a market/type. */
export interface ReferenceRevisionsPort {
  current(marketId: string, typeId: string): Promise<Readonly<Record<string, string>> | null>;
}
