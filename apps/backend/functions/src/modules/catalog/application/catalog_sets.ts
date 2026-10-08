import { randomUUID } from 'node:crypto';

import type { ServerClock } from '../../../shared/server_clock.js';
import { catalogTestOnlyConfig } from '../domain/catalog_config.js';
import type { CatalogRepository, ProjectionSetRecord } from '../domain/repositories.js';
import type { CatalogProjector } from './catalog_projector.js';
import type { CatalogReconciler, ReconcileReport } from './catalog_reconciler.js';
import type { ContentCatalogSource, SourcePointer } from './ports.js';

export type ActivationResult =
  | { readonly ok: true; readonly setId: string; readonly previousSetId: string | null }
  | {
      readonly ok: false;
      readonly code:
        | 'active_moved'
        | 'set_unknown'
        | 'set_not_activatable'
        | 'parity_failed'
        | 'nothing_to_roll_back';
      readonly report?: ReconcileReport;
    };

export interface RebuildResult {
  readonly setId: string;
  readonly replayedObjects: number;
  readonly report: ReconcileReport;
}

/**
 * Projection-set lifecycle: the initial active set, an isolated rebuild from
 * the Content fact history, activation by an atomic pointer change that checks
 * the expected active set, and rollback to the previous set. A set is never
 * queryable before activation; activation and rollback first close every gap
 * against current Content, so neither can serve an object Content has hidden.
 */
export class CatalogSets {
  constructor(
    private readonly repository: CatalogRepository,
    private readonly source: ContentCatalogSource,
    private readonly projector: CatalogProjector,
    private readonly reconciler: CatalogReconciler,
    private readonly clock: ServerClock,
  ) {}

  /** The active set; an empty initial set is created and activated once. */
  async ensureActive(): Promise<ProjectionSetRecord> {
    const nowUtc = this.clock.now().toISOString();
    return this.repository.transact(async (tx) => {
      const pointer = await tx.activePointer();
      if (pointer !== null) {
        const set = await tx.set(pointer.setId);
        if (set === null) throw new Error('catalog_active_set_missing');
        return set;
      }
      const set: ProjectionSetRecord = {
        setId: 'catalog-set-initial',
        status: 'active',
        origin: 'initial',
        revision: 0,
        createdAtUtc: nowUtc,
        activatedAtUtc: nowUtc,
        lastSourceSyncAtUtc: null,
        deliveryCheckpoint: null,
      };
      tx.putSet(set);
      tx.putActivePointer({
        setId: set.setId,
        previousSetId: null,
        pointerRevision: 1,
        updatedAtUtc: nowUtc,
      });
      return set;
    });
  }

  async active(): Promise<ProjectionSetRecord | null> {
    return this.repository.transact(async (tx) => {
      const pointer = await tx.activePointer();
      return pointer === null ? null : tx.set(pointer.setId);
    });
  }

  /**
   * Builds a new, inactive set by replaying every object's stored facts from
   * the start (BCK-08-AC-61), then checks parity against current pointers
   * without repairing. Deliveries keep going to the active set meanwhile.
   */
  async rebuild(): Promise<RebuildResult> {
    const nowUtc = this.clock.now().toISOString();
    const setId = `catalog-set-${Date.now()}-${randomUUID().slice(0, 8)}`;
    // Facts committed after this point reach the new set through activation's catch-up.
    const checkpoint = await this.source.latestEffect();
    await this.repository.transact((tx) => {
      tx.putSet({
        setId,
        status: 'building',
        origin: 'rebuild',
        revision: 0,
        createdAtUtc: nowUtc,
        activatedAtUtc: null,
        lastSourceSyncAtUtc: null,
        deliveryCheckpoint: checkpoint,
      });
    });
    let replayedObjects = 0;
    let after: string | null = null;
    for (;;) {
      const pointers: readonly SourcePointer[] = await this.source.pointersPage(
        after,
        catalogTestOnlyConfig.rebuildBatchSize,
      );
      for (const pointer of pointers) {
        let cursor: { pointerRevision: number; effectId: string } | null = null;
        for (;;) {
          const facts = await this.source.effectsForContent(
            pointer.contentId,
            cursor,
            catalogTestOnlyConfig.rebuildBatchSize,
          );
          for (const fact of facts) await this.projector.consumeContentFact(setId, fact);
          const last = facts[facts.length - 1];
          if (last === undefined || facts.length < catalogTestOnlyConfig.rebuildBatchSize) break;
          cursor = { pointerRevision: last.pointerRevision, effectId: last.effectId };
        }
        replayedObjects += 1;
      }
      if (pointers.length < catalogTestOnlyConfig.rebuildBatchSize) break;
      after = pointers[pointers.length - 1]?.contentId ?? null;
    }
    const report = await this.reconciler.reconcile(setId, { repair: false, kind: 'rebuild' });
    return { setId, replayedObjects, report };
  }

  /** Atomic activation of a complete set; `expectedActiveSetId` guards against a race. */
  async activate(setId: string, expectedActiveSetId: string | null): Promise<ActivationResult> {
    const known = await this.repository.transact((tx) => tx.set(setId));
    if (known === null) return { ok: false, code: 'set_unknown' };
    if (known.status === 'active') return { ok: false, code: 'set_not_activatable' };
    // A retired set (rollback target) is reopened for catch-up; it serves nothing
    // until the pointer moves, because queries only read the active set.
    if (known.status === 'retired')
      await this.repository.transact(async (tx) => {
        const set = await tx.set(setId);
        if (set?.status === 'retired') tx.putSet({ ...set, status: 'building' });
      });
    // Catch up with facts committed since the build, then require full parity.
    const report = await this.reconciler.reconcile(setId, { repair: true });
    if (!report.complete) return { ok: false, code: 'parity_failed', report };
    const nowUtc = this.clock.now().toISOString();
    return this.repository.transact(async (tx): Promise<ActivationResult> => {
      const pointer = await tx.activePointer();
      if ((pointer?.setId ?? null) !== expectedActiveSetId)
        return { ok: false, code: 'active_moved' };
      const target = await tx.set(setId);
      if (target === null) return { ok: false, code: 'set_unknown' };
      if (target.status === 'active') return { ok: false, code: 'set_not_activatable' };
      const previous = pointer === null ? null : await tx.set(pointer.setId);
      if (previous !== null) tx.putSet({ ...previous, status: 'retired' });
      tx.putSet({ ...target, status: 'active', activatedAtUtc: nowUtc });
      tx.putActivePointer({
        setId,
        previousSetId: pointer?.setId ?? null,
        pointerRevision: (pointer?.pointerRevision ?? 0) + 1,
        updatedAtUtc: nowUtc,
      });
      return { ok: true, setId, previousSetId: pointer?.setId ?? null };
    });
  }

  /** Re-activates the previous set (after the same catch-up and parity check). */
  async rollback(expectedActiveSetId: string): Promise<ActivationResult> {
    const pointer = await this.repository.transact((tx) => tx.activePointer());
    if (pointer?.setId !== expectedActiveSetId) return { ok: false, code: 'active_moved' };
    if (pointer.previousSetId === null) return { ok: false, code: 'nothing_to_roll_back' };
    return this.activate(pointer.previousSetId, expectedActiveSetId);
  }
}
