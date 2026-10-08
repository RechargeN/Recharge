import type {
  ReferenceDataPort,
  ReferenceResolution,
} from '../application/ports/reference_data_port.js';

/**
 * TEST-ONLY synthetic reference data for the local `demo-recharge` Emulator.
 * It answers with constants (market LV, EUR, Europe/Riga, every subcategory
 * applies, no required criteria, a Latvia bounding box as the service area).
 * It is not accepted MarketConfig, taxonomy or localization: it proves only
 * that Content pins and consults reference revisions, not that a category or
 * market rule is right. Any market other than LV is disabled.
 */
export const emulatorReferenceEvidence =
  'synthetic reference data: constants for LV, not accepted MarketConfig or taxonomy';

export class EmulatorSyntheticReferenceData implements ReferenceDataPort {
  resolve(input: { readonly marketId: string }): Promise<ReferenceResolution> {
    if (input.marketId !== 'LV') return Promise.resolve({ ok: false, code: 'market_disabled' });
    return Promise.resolve({
      ok: true,
      revisions: {
        marketConfigRevisionId: 'test-only-mc-lv-1',
        taxonomyRevisionId: 'test-only-tx-1',
        localizationRevisionId: 'test-only-loc-1',
      },
      market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
      lookups: {
        supportsLocale: (locale: string) => ['en', 'ru', 'lv'].includes(locale),
        subcategoryApplies: () => true,
        requiredCriteria: () => [] as readonly string[],
        pointInServiceArea: (latitude: number, longitude: number) =>
          latitude > 55.6 && latitude < 58.1 && longitude > 20.9 && longitude < 28.3,
      },
    } as ReferenceResolution);
  }
}
