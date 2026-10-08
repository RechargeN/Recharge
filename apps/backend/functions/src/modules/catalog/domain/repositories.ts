import type { CatalogEventItem } from './catalog_item.js';

/** Global delivery position in the Content fact feed. */
export interface FeedCheckpoint {
  readonly occurredAtUtc: string;
  readonly effectId: string;
}

/**
 * One projection set. Items are versioned inside it: every applied fact raises
 * `revision`, and a query pins one revision (MVCC), so new facts never shift a
 * snapshot that is being paged. Rebuilds write a new set that is not queryable
 * until it is activated.
 */
export interface ProjectionSetRecord {
  readonly setId: string;
  readonly status: 'building' | 'active' | 'retired';
  readonly origin: 'initial' | 'rebuild';
  readonly revision: number;
  readonly createdAtUtc: string;
  readonly activatedAtUtc: string | null;
  /** Last delivery or reconciliation that finished without an open gap. */
  readonly lastSourceSyncAtUtc: string | null;
  /** Advanced only together with a successfully processed fact. */
  readonly deliveryCheckpoint: FeedCheckpoint | null;
}

export interface ActivePointerRecord {
  readonly setId: string;
  readonly previousSetId: string | null;
  readonly pointerRevision: number;
  readonly updatedAtUtc: string;
}

/** One version of one object in one set: valid for `[validFrom, validTo)`. */
export interface ItemVersionRecord {
  readonly versionId: string;
  readonly setId: string;
  readonly contentId: string;
  readonly typeId: string;
  readonly marketId: string;
  readonly validFromRevision: number;
  readonly validToRevision: number | null;
  readonly state: 'listed' | 'excluded';
  readonly reason: string | null;
  readonly item: CatalogEventItem | null;
  readonly sourcePointerRevision: number;
  readonly effectId: string;
  readonly publishedRevisionId: string;
  readonly projectedAtUtc: string;
}

/** Per object and set: the newest source revision applied (the stale guard). */
export interface SourceStateRecord {
  readonly setId: string;
  readonly contentId: string;
  readonly lastAppliedPointerRevision: number;
  readonly lastEffectId: string;
  readonly currentVersionId: string;
}

/** Immutable record of one processed fact (dedupe and conflict detection). */
export interface FactReceiptRecord {
  readonly setId: string;
  readonly effectId: string;
  readonly payloadHash: string;
  readonly outcome: 'applied' | 'stale';
  readonly catalogRevision: number | null;
  readonly projection: 'listed' | 'excluded' | null;
  readonly reason: string | null;
  readonly recordedAtUtc: string;
}

export interface CatalogFinding {
  readonly code:
    | 'gap'
    | 'source_effect_missing'
    | 'catalog_ahead'
    | 'revision_mismatch'
    | 'orphan'
    | 'fact_conflict'
    | 'source_unavailable';
  readonly contentId: string;
  readonly detail: string;
}

export interface CatalogReportRecord {
  readonly reportId: string;
  readonly setId: string;
  readonly kind: 'delivery' | 'reconcile' | 'rebuild';
  readonly findings: readonly CatalogFinding[];
  readonly recovered: number;
  readonly complete: boolean;
  readonly createdAtUtc: string;
}

export interface CatalogTransaction {
  set(setId: string): Promise<ProjectionSetRecord | null>;
  putSet(record: ProjectionSetRecord): void;
  activePointer(): Promise<ActivePointerRecord | null>;
  putActivePointer(record: ActivePointerRecord): void;
  receipt(setId: string, effectId: string): Promise<FactReceiptRecord | null>;
  /** Create-only. */
  putReceipt(record: FactReceiptRecord): void;
  sourceState(setId: string, contentId: string): Promise<SourceStateRecord | null>;
  putSourceState(record: SourceStateRecord): void;
  itemVersion(versionId: string): Promise<ItemVersionRecord | null>;
  putItemVersion(record: ItemVersionRecord): void;
}

export interface CatalogRepository {
  transact<T>(operation: (transaction: CatalogTransaction) => T | Promise<T>): Promise<T>;
  /** All versions of one market/type in a set (bounded by the caller). */
  versionsForSet(
    setId: string,
    marketId: string,
    typeId: string,
    limit: number,
  ): Promise<readonly ItemVersionRecord[]>;
  versionsForContent(setId: string, contentId: string): Promise<readonly ItemVersionRecord[]>;
  sourceStates(
    setId: string,
    afterContentId: string | null,
    limit: number,
  ): Promise<readonly SourceStateRecord[]>;
  putReport(report: CatalogReportRecord): Promise<void>;
}
