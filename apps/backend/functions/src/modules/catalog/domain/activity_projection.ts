import type { TaxonomyDataset } from '../../reference_data/domain/taxonomy_dataset.js';
import {
  normalizeText,
  type CatalogActivityItem,
  type ContentFact,
  type ProjectionOutcome,
  type SourceRevision,
} from './catalog_item.js';
function obj(v: unknown): Record<string, unknown> | null {
  return typeof v === 'object' && v !== null && !Array.isArray(v)
    ? (v as Record<string, unknown>)
    : null;
}
function range(v: unknown): { min: number; max: number } | null {
  const r = obj(v);
  return r &&
    Number.isSafeInteger(r.min) &&
    Number.isSafeInteger(r.max) &&
    (r.min as number) > 0 &&
    (r.max as number) >= (r.min as number)
    ? { min: r.min as number, max: r.max as number }
    : null;
}
export function projectActivity(
  fact: ContentFact,
  source: SourceRevision,
  taxonomy: TaxonomyDataset | undefined,
): ProjectionOutcome {
  const bad = (): ProjectionOutcome => ({ state: 'excluded', reason: 'invalid_projection' });
  const b = source.body,
    l = obj(b.location),
    duration = range(b.typicalDurationMinutes);
  if (
    !taxonomy ||
    !taxonomy.categories
      .find((c) => c.id === b.categoryId)
      ?.subcategories.some(
        (s) => s.id === b.subcategoryId && s.applicableTypes.includes('activity'),
      )
  )
    return bad();
  if (
    !l ||
    l.pinConfirmed !== true ||
    typeof l.latitude !== 'number' ||
    typeof l.longitude !== 'number' ||
    !Number.isFinite(l.latitude) ||
    !Number.isFinite(l.longitude) ||
    Math.abs(l.latitude) > 90 ||
    Math.abs(l.longitude) > 180 ||
    !duration ||
    typeof b.title !== 'string' ||
    typeof b.shortDescription !== 'string'
  )
    return bad();
  const pair = taxonomy.categories
    .find((c) => c.id === b.categoryId)
    ?.subcategories.find((s) => s.id === b.subcategoryId);
  const profile = taxonomy.profiles.find((p) => p.id === pair?.profileId),
    criteria = obj(b.criteria);
  if (
    !profile ||
    profile.requiredFieldIds.some(
      (id) =>
        criteria?.[id] === undefined ||
        criteria[id] === null ||
        (typeof criteria[id] === 'string' && criteria[id].trim() === ''),
    )
  )
    return bad();
  const media = obj(b.media),
    cover = obj(media?.coverImage),
    suppressed = new Set(fact.suppressedMediaIds ?? []);
  const mediaId = (v: unknown): string | null => {
    const id = obj(v)?.mediaId;
    return typeof id === 'string' && !suppressed.has(id) ? id : null;
  };
  const group = b.suggestedGroupSize === undefined ? undefined : range(b.suggestedGroupSize);
  if (group === null) return bad();
  const best = obj(b.bestTime),
    caution = obj(b.accessCaution),
    contributionValue = obj(b.optionalContribution),
    contribution =
      contributionValue && Object.keys(contributionValue).length > 0 ? contributionValue : null,
    amount = obj(contribution?.amountHint);
  if (
    b.bestTime !== undefined &&
    (!best ||
      (best.timeOfDay !== undefined &&
        !['morning', 'afternoon', 'evening', 'night', 'any'].includes(best.timeOfDay as string)) ||
      (best.season !== undefined &&
        !['winter', 'spring', 'summer', 'autumn', 'any'].includes(best.season as string)))
  )
    return bad();
  if (
    contribution &&
    (!['purchase', 'donation', 'other'].includes(contribution.kind as string) ||
      typeof contribution.note !== 'string' ||
      (amount &&
        (!Number.isSafeInteger(amount.amountMinor) ||
          (amount.amountMinor as number) <= 0 ||
          typeof amount.currencyCode !== 'string')))
  )
    return bad();
  const item: CatalogActivityItem = {
    schemaRevision: 'catalog-activity-projection-v1',
    typeId: 'activity',
    contentId: fact.contentId,
    publishedRevisionId: fact.publishedRevisionId,
    sourcePointerRevision: fact.pointerRevision,
    marketId: fact.marketId,
    publisherRef: { ...fact.publisherRef },
    title: b.title,
    shortDescription: b.shortDescription,
    categoryId: b.categoryId as string,
    subcategoryId: b.subcategoryId as string,
    point: { latitude: l.latitude, longitude: l.longitude },
    typicalDurationMinutes: duration,
    ...(typeof l.linkedPlaceId === 'string' ? { linkedPlaceId: l.linkedPlaceId } : {}),
    coverMediaId: mediaId(cover),
    galleryMediaIds: Array.isArray(media?.gallery)
      ? media.gallery.map(mediaId).filter((id): id is string => id !== null)
      : [],
    referenceRevisions: { ...source.referenceRevisions },
    publishedAtUtc: source.publishedAtUtc,
    searchText: normalizeText(
      [
        b.title,
        b.shortDescription,
        b.categoryId,
        b.subcategoryId,
        l.addressLine ?? '',
        l.accessNotes ?? '',
      ].join(' '),
    ),
    ...(typeof b.fullDescription === 'string' ? { fullDescription: b.fullDescription } : {}),
    ...(typeof l.addressLine === 'string' ? { addressLine: l.addressLine } : {}),
    ...(typeof l.accessNotes === 'string' ? { accessNotes: l.accessNotes } : {}),
    ...(group ? { suggestedGroupSize: group } : {}),
    ...(caution && typeof caution.isInformal === 'boolean'
      ? {
          accessCaution: {
            isInformal: caution.isInformal,
            ...(typeof caution.note === 'string' ? { note: caution.note } : {}),
          },
        }
      : {}),
    ...(best
      ? {
          bestTime: {
            ...(typeof best.timeOfDay === 'string' ? { timeOfDay: best.timeOfDay } : {}),
            ...(typeof best.season === 'string' ? { season: best.season } : {}),
          },
        }
      : {}),
    ...(contribution
      ? {
          optionalContribution: {
            kind: contribution.kind as string,
            note: contribution.note as string,
            ...(amount
              ? {
                  amountHint: {
                    amountMinor: amount.amountMinor as number,
                    currencyCode: amount.currencyCode as string,
                  },
                }
              : {}),
          },
        }
      : {}),
  };
  return { state: 'listed', item };
}
