import type {
  ReferenceDataPort,
  ReferenceResolution,
} from '../application/ports/reference_data_port.js';
import {
  readLocalTaxonomy,
  taxonomyPair,
  taxonomyRevisionId,
  type TaxonomyRead,
} from '../../reference_data/infrastructure/local_taxonomy_reader.js';
import {
  emulatorPlaceTaxonomyRevisionId,
  placeRequiredCriteria,
  placeSubcategoryApplies,
} from './emulator_place_taxonomy.js';

/** Local demo-recharge composition: synthetic LV market/localization and Place fixture;
 * Activity uses the deterministic immutable BCK-20 artifact derived from the
 * accepted Category System v1.4.3 semantic source. No production MarketConfig.
 */
export const emulatorReferenceEvidence =
  'synthetic LV market/localization and Place fixture; Activity taxonomy derived from accepted Category System v1.4.3';

export class EmulatorSyntheticReferenceData implements ReferenceDataPort {
  readTaxonomyRevision(input: { readonly taxonomyRevisionId: string }): Promise<TaxonomyRead> {
    return Promise.resolve(readLocalTaxonomy(input.taxonomyRevisionId));
  }
  resolve(input: {
    readonly marketId: string;
    readonly typeId?: string;
  }): Promise<ReferenceResolution> {
    if (input.marketId !== 'LV') return Promise.resolve({ ok: false, code: 'market_disabled' });
    const place = input.typeId === 'place';
    const activity = input.typeId === 'activity';
    const taxonomy = readLocalTaxonomy(taxonomyRevisionId);
    if (activity && !taxonomy.ok) return Promise.resolve({ ok: false, code: 'policy_unavailable' });
    const dataset = taxonomy.ok ? taxonomy.dataset : undefined;
    return Promise.resolve({
      ok: true,
      revisions: {
        marketConfigRevisionId: 'test-only-mc-lv-1',
        taxonomyRevisionId: place
          ? emulatorPlaceTaxonomyRevisionId
          : activity
            ? taxonomyRevisionId
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
              ? dataset === undefined
                ? undefined
                : (taxonomyPair(dataset, categoryId, subcategoryId)?.applicableTypes.includes(
                    'activity',
                  ) ?? false)
              : true,
        requiredCriteria: (typeId: string, categoryId: string, subcategoryId: string) => {
          if (typeId === 'place') return placeRequiredCriteria(categoryId, subcategoryId);
          if (typeId !== 'activity') return [];
          if (dataset === undefined) return undefined;
          const pair = taxonomyPair(dataset, categoryId, subcategoryId);
          if (!pair?.applicableTypes.includes('activity')) return [];
          return dataset.profiles.find((profile) => profile.id === pair.profileId)
            ?.requiredFieldIds;
        },
        pointInServiceArea: (latitude: number, longitude: number) =>
          latitude > 55.6 && latitude < 58.1 && longitude > 20.9 && longitude < 28.3,
      },
    } as ReferenceResolution);
  }
}
