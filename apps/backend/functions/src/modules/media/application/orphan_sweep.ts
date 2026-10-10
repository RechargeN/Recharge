import type { OrphanReconciliationV1 } from '../../../contracts/media_v1.js';
import type { MediaRepository } from '../domain/repositories.js';
import type { OrphanReconciler } from './orphan_reconciler.js';

export interface OrphanSweepReport {
  readonly checked: number;
  /** How many assets each reconciliation action applied to. */
  readonly actions: Readonly<Record<OrphanReconciliationV1['action'], number>>;
  /** Refusals by code, e.g. `policy_unavailable` without an accepted retention policy. */
  readonly refused: Readonly<Record<string, number>>;
}

/**
 * R2 (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §8): every asset, page by page,
 * through the existing `media.reconcileOrphan` logic. The reconciler asks the
 * owning domain about references before any transaction, counts doubt as a
 * reference and never touches a restriction; without an accepted retention
 * policy it refuses with `policy_unavailable` and nothing is deleted.
 */
export class OrphanSweep {
  constructor(
    private readonly deps: {
      readonly repository: MediaRepository;
      readonly reconciler: OrphanReconciler;
      readonly batchSize?: number;
    },
  ) {}

  async sweep(): Promise<OrphanSweepReport> {
    const batchSize = this.deps.batchSize ?? 50;
    const actions: Record<OrphanReconciliationV1['action'], number> = {
      keep: 0,
      marked: 0,
      unmarked: 0,
      deleting: 0,
      deleted: 0,
      recovered: 0,
    };
    const refused: Record<string, number> = {};
    let checked = 0;
    let cursor: string | null = null;
    for (;;) {
      const page = await this.deps.repository.transact((tx) => tx.assetIdsPage(cursor, batchSize));
      for (const assetId of page) {
        checked += 1;
        const result = await this.deps.reconciler.reconcile({
          schemaVersion: 1,
          commandType: 'reconcileOrphan',
          idempotencyKey: `orphan-sweep:${assetId}`,
          payload: { assetId },
        });
        if (result.kind === 'succeeded') actions[result.data.action] += 1;
        else refused[result.code] = (refused[result.code] ?? 0) + 1;
      }
      const last = page[page.length - 1];
      if (last === undefined || page.length < batchSize) break;
      cursor = last;
    }
    return { checked, actions, refused };
  }
}
