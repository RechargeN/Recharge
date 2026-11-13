/**
 * TEST-ONLY Place taxonomy of the local `demo-recharge` Emulator (D3.1 §2.3).
 * A minimal subset of the mobile taxonomy (groups, subcategories, whether a
 * subcategory applies to Place and the required criteria of its profile),
 * equal to `packages/api_contracts/schema/content/v1/fixtures/place_reference_taxonomy.json`.
 * It is not the accepted BCK-20 taxonomy: it proves only that Content applies
 * applicability and required criteria to Place, not that a category is right.
 */
export interface EmulatorPlaceTaxonomyEntry {
  readonly categoryId: string;
  readonly subcategoryId: string;
  readonly appliesToPlace: boolean;
  readonly profileId: string;
  readonly requiredCriteria: readonly string[];
}

export const emulatorPlaceTaxonomyRevisionId = 'test-only-tx-place-1';

export const emulatorPlaceTaxonomy: readonly EmulatorPlaceTaxonomyEntry[] = Object.freeze([
  {
    categoryId: 'art_culture_museums',
    subcategoryId: 'museum',
    appliesToPlace: true,
    profileId: 'exhibition_visit',
    requiredCriteria: [],
  },
  {
    categoryId: 'art_culture_museums',
    subcategoryId: 'gallery',
    appliesToPlace: true,
    profileId: 'exhibition_visit',
    requiredCriteria: [],
  },
  {
    categoryId: 'art_culture_museums',
    subcategoryId: 'artist_talk',
    appliesToPlace: false,
    profileId: 'talk_lecture',
    requiredCriteria: ['language'],
  },
  {
    categoryId: 'outdoor_nature_walking',
    subcategoryId: 'park',
    appliesToPlace: true,
    profileId: 'outdoor_activity',
    requiredCriteria: ['difficulty'],
  },
  {
    categoryId: 'outdoor_nature_walking',
    subcategoryId: 'lake',
    appliesToPlace: true,
    profileId: 'outdoor_activity',
    requiredCriteria: ['difficulty'],
  },
]);

function entryFor(categoryId: string, subcategoryId: string): EmulatorPlaceTaxonomyEntry | null {
  return (
    emulatorPlaceTaxonomy.find(
      (item) => item.categoryId === categoryId && item.subcategoryId === subcategoryId,
    ) ?? null
  );
}

/** An unknown group/subcategory pair does not apply to Place. */
export function placeSubcategoryApplies(categoryId: string, subcategoryId: string): boolean {
  return entryFor(categoryId, subcategoryId)?.appliesToPlace ?? false;
}

/**
 * Required criteria of an applicable pair; none for a pair that does not apply,
 * so that a refusal names the inapplicable subcategory and nothing else.
 */
export function placeRequiredCriteria(
  categoryId: string,
  subcategoryId: string,
): readonly string[] {
  const entry = entryFor(categoryId, subcategoryId);
  return entry?.appliesToPlace === true ? entry.requiredCriteria : [];
}
