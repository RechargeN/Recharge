import { deepFreeze } from '../../../shared/immutable.js';
import { createHash } from 'node:crypto';
import {
  taxonomyPayload,
  taxonomyArtifactHash,
  taxonomyRevisionId,
} from './taxonomy_dataset.generated.js';

export { taxonomyRevisionId };
import type { TaxonomyDataset, TaxonomyRead } from '../domain/taxonomy_dataset.js';
export type { TaxonomyDataset, TaxonomyRead } from '../domain/taxonomy_dataset.js';

/** Generated immutable BCK-20 artifact; exact ID only, never latest or fixture. */
export function readLocalTaxonomy(
  revisionId: string,
  payload: string | null = taxonomyPayload,
): TaxonomyRead {
  if (revisionId !== taxonomyRevisionId) return { ok: false, code: 'taxonomy_revision_unknown' };
  if (payload === null) return { ok: false, code: 'taxonomy_revision_unavailable' };
  if (createHash('sha256').update(payload).digest('hex') !== taxonomyArtifactHash)
    return { ok: false, code: 'taxonomy_integrity_failed' };
  const dataset = JSON.parse(payload) as TaxonomyDataset;
  return deepFreeze({ ok: true, revisionId, artifactSha256: taxonomyArtifactHash, dataset });
}
export function taxonomyPair(dataset: TaxonomyDataset, categoryId: string, subcategoryId: string) {
  return dataset.categories
    .find((category) => category.id === categoryId)
    ?.subcategories.find((subcategory) => subcategory.id === subcategoryId);
}
