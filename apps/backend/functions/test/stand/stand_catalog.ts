import type { Firestore } from 'firebase-admin/firestore';

import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';

/**
 * Stand command for the local Catalog (E1). Delivery is manual: nothing runs
 * automatically. Every action goes through the Catalog application layer
 * (projector, reconciler, set lifecycle, query service); this file never
 * writes a projection itself.
 */
export async function runCatalog(firestore: Firestore, args: readonly string[]): Promise<unknown> {
  const catalog = createEmulatorCatalogComposition(firestore);
  const [action, first, second] = args;
  if (action === 'deliver') {
    const active = await catalog.sets.ensureActive();
    return catalog.projector.deliverFromContent(active.setId);
  }
  if (action === 'reconcile') {
    const active = await catalog.sets.ensureActive();
    return catalog.reconciler.reconcile(active.setId);
  }
  if (action === 'status') return catalog.sets.active();
  if (action === 'rebuild') {
    const result = await catalog.sets.rebuild();
    return {
      setId: result.setId,
      replayedObjects: result.replayedObjects,
      complete: result.report.complete,
      findings: result.report.findings,
    };
  }
  if (action === 'activate' && first !== undefined)
    return catalog.sets.activate(first, second === undefined || second === 'none' ? null : second);
  if (action === 'rollback' && first !== undefined) return catalog.sets.rollback(first);
  if (action === 'feed') {
    const query =
      first === undefined ? { schemaVersion: 1, marketId: 'LV' } : (JSON.parse(first) as unknown);
    const page = await catalog.query.feed({ query });
    if (page.kind !== 'succeeded') return page;
    return {
      kind: page.kind,
      projectionSetId: page.snapshot.projectionSetId,
      projectionSetRevision: page.snapshot.projectionSetRevision,
      freshness: page.freshness,
      totalEligible: page.totalEligible,
      items: page.items.map((item) => ({
        contentId: item.ref.contentId,
        title: item.title,
        ...('occurrence' in item ? { start: item.occurrence.startAtUtc } : {}),
        ...('availability' in item ? { availability: item.availability.status } : {}),
      })),
    };
  }
  if (action === 'details' && first !== undefined)
    return catalog.query.details({ contentId: first });
  throw new Error(
    'usage: catalog deliver | reconcile | status | rebuild | activate <setId> <expectedActiveSetId|none> | rollback <expectedActiveSetId> | feed [<query json>] | details <contentId>',
  );
}
