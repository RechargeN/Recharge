import { createHash, randomUUID } from 'node:crypto';

import type { ServerClock } from '../../../shared/server_clock.js';
import { catalogTestOnlyConfig } from '../domain/catalog_config.js';
import {
  projectFact,
  type ContentFact,
  type ProjectionOutcome,
  type SourceRevision,
} from '../domain/catalog_item.js';
import type {
  CatalogFinding,
  CatalogRepository,
  FeedCheckpoint,
  ItemVersionRecord,
} from '../domain/repositories.js';
import type { ContentCatalogSource } from './ports.js';

export type FactReceipt =
  | {
      readonly outcome: 'applied';
      readonly projection: 'listed' | 'excluded';
      readonly reason: string | null;
      readonly catalogRevision: number;
    }
  | { readonly outcome: 'deduped' }
  /** An older source revision than the one applied: it changes nothing. */
  | { readonly outcome: 'stale'; readonly lastAppliedPointerRevision: number }
  /** Same fact id with other content: nothing is mutated. */
  | { readonly outcome: 'conflict' }
  | {
      readonly outcome: 'refused';
      readonly code: 'fact_invalid' | 'set_not_writable' | 'source_unavailable';
    };

export interface DeliveryReport {
  readonly setId: string;
  readonly processed: number;
  readonly applied: number;
  readonly deduped: number;
  readonly stale: number;
  readonly conflicts: number;
  /** Set when the run stopped on a fact it could not process; the checkpoint stays before it. */
  readonly stoppedAt: { readonly effectId: string; readonly code: string } | null;
  readonly checkpoint: FeedCheckpoint | null;
  /** True when the run reached the end of the feed without stopping. */
  readonly synced: boolean;
}

export interface CatalogProjectorDependencies {
  readonly repository: CatalogRepository;
  readonly source: ContentCatalogSource;
  readonly clock: ServerClock;
}

function canonical(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value) ?? 'null';
  if (Array.isArray(value)) return `[${value.map((item) => canonical(item)).join(',')}]`;
  const object = value as Record<string, unknown>;
  return `{${Object.keys(object)
    .filter((key) => object[key] !== undefined)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonical(object[key])}`)
    .join(',')}}`;
}

/** Shape check of a committed Content fact; anything else is refused. */
export function parseFact(raw: unknown): ContentFact | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const value = raw as Record<string, unknown>;
  const publisher = value.publisherRef as Record<string, unknown> | undefined;
  if (
    value.schemaVersion !== 1 ||
    typeof value.effectId !== 'string' ||
    value.effectId.length === 0 ||
    value.effectId.length > 200 ||
    typeof value.kind !== 'string' ||
    typeof value.contentId !== 'string' ||
    typeof value.publishedRevisionId !== 'string' ||
    typeof value.pointerRevision !== 'number' ||
    !Number.isInteger(value.pointerRevision) ||
    value.pointerRevision < 1 ||
    typeof value.visibility !== 'string' ||
    typeof value.typeId !== 'string' ||
    typeof publisher?.type !== 'string' ||
    typeof publisher.id !== 'string' ||
    typeof value.marketId !== 'string' ||
    typeof value.occurredAtUtc !== 'string' ||
    typeof value.referenceRevisions !== 'object' ||
    value.referenceRevisions === null
  )
    return null;
  // D2: optional, bounded list of plain ids.
  const suppressed = value.suppressedMediaIds;
  if (
    suppressed !== undefined &&
    (!Array.isArray(suppressed) ||
      suppressed.length > 100 ||
      suppressed.some((item) => typeof item !== 'string' || item.length === 0))
  )
    return null;
  return raw as ContentFact;
}

export function factHash(fact: ContentFact): string {
  return createHash('sha256').update(canonical(fact), 'utf8').digest('hex');
}

function afterCheckpoint(fact: ContentFact, checkpoint: FeedCheckpoint | null): boolean {
  if (checkpoint === null) return true;
  if (fact.occurredAtUtc !== checkpoint.occurredAtUtc)
    return fact.occurredAtUtc > checkpoint.occurredAtUtc;
  return fact.effectId > checkpoint.effectId;
}

/**
 * The only writer of Catalog items. A fact is applied in one transaction with
 * its receipt, the per-object source state and the set revision, so a failure
 * leaves nothing behind. Repeats are deduped by fact id; a fact older than the
 * applied source revision (including a replay after hide/withdraw) is `stale`
 * and changes nothing; a hidden state is just another, higher revision, so it
 * can never be overtaken by an older visible one.
 */
export class CatalogProjector {
  readonly #deps: CatalogProjectorDependencies;

  constructor(deps: CatalogProjectorDependencies) {
    this.#deps = deps;
  }

  async consumeContentFact(
    setId: string,
    rawFact: unknown,
    options: { readonly advanceCheckpoint?: boolean } = {},
  ): Promise<FactReceipt> {
    const fact = parseFact(rawFact);
    if (fact === null) return { outcome: 'refused', code: 'fact_invalid' };
    const hash = factHash(fact);

    // Immutable source revision, read outside the Catalog transaction.
    let revision: SourceRevision | null = null;
    if (fact.visibility === 'visible') {
      try {
        revision = await this.#deps.source.publishedRevision(fact.publishedRevisionId);
      } catch {
        return { outcome: 'refused', code: 'source_unavailable' };
      }
    }
    const outcome: ProjectionOutcome = projectFact({
      fact,
      revision,
      typeVisibilityPolicy: this.#deps.source.typeVisibilityPolicy(fact.typeId),
    });
    const nowUtc = this.#deps.clock.now().toISOString();

    return this.#deps.repository.transact(async (tx): Promise<FactReceipt> => {
      const set = await tx.set(setId);
      if (set === null || set.status === 'retired')
        return { outcome: 'refused', code: 'set_not_writable' };
      const checkpoint =
        options.advanceCheckpoint === true && afterCheckpoint(fact, set.deliveryCheckpoint)
          ? { occurredAtUtc: fact.occurredAtUtc, effectId: fact.effectId }
          : set.deliveryCheckpoint;
      const prior = await tx.receipt(setId, fact.effectId);
      if (prior !== null) {
        if (prior.payloadHash !== hash) return { outcome: 'conflict' };
        if (checkpoint !== set.deliveryCheckpoint)
          tx.putSet({ ...set, deliveryCheckpoint: checkpoint });
        return { outcome: 'deduped' };
      }
      const state = await tx.sourceState(setId, fact.contentId);
      if (state !== null && state.lastAppliedPointerRevision >= fact.pointerRevision) {
        tx.putReceipt({
          setId,
          effectId: fact.effectId,
          payloadHash: hash,
          outcome: 'stale',
          catalogRevision: null,
          projection: null,
          reason: null,
          recordedAtUtc: nowUtc,
        });
        if (checkpoint !== set.deliveryCheckpoint)
          tx.putSet({ ...set, deliveryCheckpoint: checkpoint });
        return { outcome: 'stale', lastAppliedPointerRevision: state.lastAppliedPointerRevision };
      }
      const nextRevision = set.revision + 1;
      if (state !== null) {
        const current = await tx.itemVersion(state.currentVersionId);
        if (current !== null) tx.putItemVersion({ ...current, validToRevision: nextRevision });
      }
      const version: ItemVersionRecord = {
        versionId: `${setId}~${fact.contentId}~${nextRevision}`,
        setId,
        contentId: fact.contentId,
        typeId: fact.typeId,
        marketId: fact.marketId,
        validFromRevision: nextRevision,
        validToRevision: null,
        state: outcome.state,
        reason: outcome.state === 'excluded' ? outcome.reason : null,
        item: outcome.state === 'listed' ? outcome.item : null,
        sourcePointerRevision: fact.pointerRevision,
        effectId: fact.effectId,
        publishedRevisionId: fact.publishedRevisionId,
        projectedAtUtc: nowUtc,
      };
      tx.putItemVersion(version);
      tx.putSourceState({
        setId,
        contentId: fact.contentId,
        lastAppliedPointerRevision: fact.pointerRevision,
        lastEffectId: fact.effectId,
        currentVersionId: version.versionId,
      });
      tx.putReceipt({
        setId,
        effectId: fact.effectId,
        payloadHash: hash,
        outcome: 'applied',
        catalogRevision: nextRevision,
        projection: outcome.state,
        reason: version.reason,
        recordedAtUtc: nowUtc,
      });
      tx.putSet({ ...set, revision: nextRevision, deliveryCheckpoint: checkpoint });
      return {
        outcome: 'applied',
        projection: outcome.state,
        reason: version.reason,
        catalogRevision: nextRevision,
      };
    });
  }

  /**
   * Manual delivery (E1 has no automatic trigger): reads committed facts after
   * the set's checkpoint in batches and consumes each through
   * `consumeContentFact`. The checkpoint moves only inside the transaction that
   * processed the fact, so a stop leaves it before the failed fact and the next
   * run retries it; a conflicting fact is reported, not allowed to block.
   */
  async deliverFromContent(setId: string): Promise<DeliveryReport> {
    const counts = { processed: 0, applied: 0, deduped: 0, stale: 0, conflicts: 0 };
    const findings: CatalogFinding[] = [];
    let stoppedAt: DeliveryReport['stoppedAt'] = null;
    let checkpoint = await this.#checkpoint(setId);
    let finished = false;
    for (
      let batch = 0;
      batch < catalogTestOnlyConfig.deliveryMaxBatchesPerRun && stoppedAt === null && !finished;
      batch += 1
    ) {
      let facts: readonly ContentFact[];
      try {
        facts = await this.#deps.source.effectsAfter(
          checkpoint,
          catalogTestOnlyConfig.deliveryBatchSize,
        );
      } catch {
        stoppedAt = { effectId: '', code: 'source_unavailable' };
        break;
      }
      for (const fact of facts) {
        const receipt = await this.consumeContentFact(setId, fact, { advanceCheckpoint: true });
        if (receipt.outcome === 'refused') {
          stoppedAt = { effectId: fact.effectId, code: receipt.code };
          break;
        }
        counts.processed += 1;
        if (receipt.outcome === 'applied') counts.applied += 1;
        else if (receipt.outcome === 'deduped') counts.deduped += 1;
        else if (receipt.outcome === 'stale') counts.stale += 1;
        else {
          counts.conflicts += 1;
          findings.push({
            code: 'fact_conflict',
            contentId: fact.contentId,
            detail: fact.effectId,
          });
          // A poison fact does not block the rest of the feed.
          await this.#advanceCheckpoint(setId, {
            occurredAtUtc: fact.occurredAtUtc,
            effectId: fact.effectId,
          });
        }
      }
      checkpoint = await this.#checkpoint(setId);
      if (facts.length < catalogTestOnlyConfig.deliveryBatchSize) finished = true;
    }
    const synced = stoppedAt === null && finished;
    if (synced) await this.markSynced(setId);
    await this.#deps.repository.putReport({
      reportId: `delivery-${Date.now()}-${randomUUID().slice(0, 8)}`,
      setId,
      kind: 'delivery',
      findings,
      recovered: 0,
      complete: synced && findings.length === 0,
      createdAtUtc: this.#deps.clock.now().toISOString(),
    });
    return { setId, ...counts, stoppedAt, checkpoint, synced };
  }

  /** Records that the set matched its source at this instant. */
  async markSynced(setId: string): Promise<void> {
    const nowUtc = this.#deps.clock.now().toISOString();
    await this.#deps.repository.transact(async (tx) => {
      const set = await tx.set(setId);
      if (set !== null) tx.putSet({ ...set, lastSourceSyncAtUtc: nowUtc });
    });
  }

  async #checkpoint(setId: string): Promise<FeedCheckpoint | null> {
    return this.#deps.repository.transact(
      async (tx) => (await tx.set(setId))?.deliveryCheckpoint ?? null,
    );
  }

  async #advanceCheckpoint(setId: string, checkpoint: FeedCheckpoint): Promise<void> {
    await this.#deps.repository.transact(async (tx) => {
      const set = await tx.set(setId);
      if (set === null) return;
      const current = set.deliveryCheckpoint;
      const ahead =
        current === null ||
        checkpoint.occurredAtUtc > current.occurredAtUtc ||
        (checkpoint.occurredAtUtc === current.occurredAtUtc &&
          checkpoint.effectId > current.effectId);
      if (ahead) tx.putSet({ ...set, deliveryCheckpoint: checkpoint });
    });
  }
}
