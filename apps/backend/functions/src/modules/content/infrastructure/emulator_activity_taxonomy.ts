/**
 * TEST-ONLY Recharge Activity taxonomy of the local `demo-recharge` Emulator
 * (D3.2 §2.3). A minimal subset of the mobile taxonomy (groups, subcategories,
 * whether a subcategory applies to Activity and the required criteria of its
 * profile), equal to
 * `packages/api_contracts/schema/content/v1/fixtures/activity_reference_taxonomy.json`.
 * It is not the accepted BCK-20 taxonomy: it proves only that Content applies
 * applicability and required criteria to Activity, not that a category is right.
 * An unknown pair does not apply, so Activity never falls back to "anything goes".
 */
export interface EmulatorActivityTaxonomyEntry {
  readonly categoryId: string;
  readonly subcategoryId: string;
  readonly appliesToActivity: boolean;
  readonly profileId: string;
  readonly requiredCriteria: readonly string[];
}

export const emulatorActivityTaxonomyRevisionId = 'test-only-tx-activity-1';

export const emulatorActivityTaxonomy: readonly EmulatorActivityTaxonomyEntry[] = Object.freeze([
  {
    categoryId: 'outdoor_nature_walking',
    subcategoryId: 'forest_walk',
    appliesToActivity: true,
    profileId: 'outdoor_activity',
    requiredCriteria: ['difficulty'],
  },
  {
    categoryId: 'outdoor_nature_walking',
    subcategoryId: 'sunset_walk',
    appliesToActivity: true,
    profileId: 'outdoor_activity',
    requiredCriteria: ['difficulty'],
  },
  {
    categoryId: 'wellness_recharge',
    subcategoryId: 'meditation',
    appliesToActivity: true,
    profileId: 'wellness_session',
    requiredCriteria: [],
  },
  {
    categoryId: 'wellness_recharge',
    subcategoryId: 'sauna',
    appliesToActivity: false,
    profileId: 'wellness_session',
    requiredCriteria: [],
  },
  {
    categoryId: 'water_activities',
    subcategoryId: 'kayak',
    appliesToActivity: true,
    profileId: 'water_activity',
    requiredCriteria: ['equipment_provided', 'swimming_required'],
  },
]);

function entryFor(categoryId: string, subcategoryId: string): EmulatorActivityTaxonomyEntry | null {
  return (
    emulatorActivityTaxonomy.find(
      (item) => item.categoryId === categoryId && item.subcategoryId === subcategoryId,
    ) ?? null
  );
}

/** An unknown group/subcategory pair does not apply to Activity. */
export function activitySubcategoryApplies(categoryId: string, subcategoryId: string): boolean {
  return entryFor(categoryId, subcategoryId)?.appliesToActivity ?? false;
}

/**
 * Required criteria of an applicable pair; none for a pair that does not apply,
 * so that a refusal names the inapplicable subcategory and nothing else.
 */
export function activityRequiredCriteria(
  categoryId: string,
  subcategoryId: string,
): readonly string[] {
  const entry = entryFor(categoryId, subcategoryId);
  return entry?.appliesToActivity === true ? entry.requiredCriteria : [];
}
