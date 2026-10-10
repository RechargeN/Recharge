import type {
  ReferenceDataPort,
  ReferenceResolution,
} from '../application/ports/reference_data_port.js';
import {
  activityRequiredCriteria,
  activitySubcategoryApplies,
  emulatorActivityTaxonomyRevisionId,
} from './emulator_activity_taxonomy.js';
import {
  emulatorPlaceTaxonomyRevisionId,
  placeRequiredCriteria,
  placeSubcategoryApplies,
} from './emulator_place_taxonomy.js';

/**
 * TEST-ONLY synthetic reference data for the local `demo-recharge` Emulator.
 * It answers with constants (market LV, EUR, Europe/Riga, a Latvia bounding box
 * as the service area). Taxonomy: for Place and Recharge Activity, the minimal
 * Emulator taxonomy of that type (D3.1 §2.3, D3.2 §2.3: applicability and
 * required criteria of a few real subcategories, an unknown pair does not
 * apply); for every other type, every subcategory applies and no criteria are
 * required. It is not accepted MarketConfig, taxonomy or
 * localization: it proves only that Content pins and consults reference
 * revisions, not that a category or market rule is right. Any market other
 * than LV is disabled.
 */
export const emulatorReferenceEvidence =
  'synthetic reference data: constants for LV and test-only Place and Activity taxonomies, not accepted MarketConfig or taxonomy';

export class EmulatorSyntheticReferenceData implements ReferenceDataPort {
  resolve(input: {
    readonly marketId: string;
    readonly typeId?: string;
  }): Promise<ReferenceResolution> {
    if (input.marketId !== 'LV') return Promise.resolve({ ok: false, code: 'market_disabled' });
    const place = input.typeId === 'place';
    const activity = input.typeId === 'activity';
    return Promise.resolve({
      ok: true,
      revisions: {
        marketConfigRevisionId: 'test-only-mc-lv-1',
        taxonomyRevisionId: place
          ? emulatorPlaceTaxonomyRevisionId
          : activity
            ? emulatorActivityTaxonomyRevisionId
            : 'test-only-tx-1',
        localizationRevisionId: 'test-only-loc-1',
      },
      market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
      lookups: {
        supportsLocale: (locale: string) => ['en', 'ru', 'lv'].includes(locale),
        subcategoryApplies: (typeId: string, categoryId: string, subcategoryId: string) =>
          typeId === 'place'
            ? placeSubcategoryApplies(categoryId, subcategoryId)
            : typeId === 'activity'
              ? activitySubcategoryApplies(categoryId, subcategoryId)
              : true,
        requiredCriteria: (typeId: string, categoryId: string, subcategoryId: string) =>
          typeId === 'place'
            ? placeRequiredCriteria(categoryId, subcategoryId)
            : typeId === 'activity'
              ? activityRequiredCriteria(categoryId, subcategoryId)
              : ([] as readonly string[]),
        pointInServiceArea: (latitude: number, longitude: number) =>
          latitude > 55.6 && latitude < 58.1 && longitude > 20.9 && longitude < 28.3,
      },
    } as ReferenceResolution);
  }
}
