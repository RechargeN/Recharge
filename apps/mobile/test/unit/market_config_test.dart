import 'package:recharge/shared/primitives/market/market_ref.dart';
import 'package:recharge/shared/primitives/locale/locale_tag.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/time/iana_time_zone.dart';
import 'package:recharge/features/discover/data/models/discover_query_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/app/config/travel_policy_config.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/shared/primitives/geo/geo_point.dart';
import 'package:recharge/features/discover/domain/entities/time_window.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';

void main() {
  test(
    'market locale currency and zone are explicit independent identities',
    () {
      final locales = [LocaleTag.parse('ru'), LocaleTag.parse('en-US')];
      final config = MarketConfig(
        market: MarketRef.riga,
        countryCode: 'LV',
        cityName: 'Renamed display',
        timezone: IanaTimeZone.parse('Pacific/Honolulu'),
        currency: CurrencyCode.parse('USD'),
        defaultLocale: LocaleTag.ru,
        supportedLocales: locales,
        centerLat: 56,
        centerLng: 24,
      );
      locales.clear();
      expect(config.market, MarketRef.riga);
      expect(config.defaultLocale, LocaleTag.ru);
      expect(config.currency.value, 'USD');
      expect(config.timezone.value, 'Pacific/Honolulu');
      expect(config.supportedLocaleCodes, ['ru', 'en-US']);
      expect(() => config.supportedLocales.clear(), throwsUnsupportedError);
      expect(
        MarketRegistry(active: config, markets: [config]).byRef(MarketRef.riga),
        same(config),
      );
      final legacy = MarketConfig.legacy(
        marketCityId: 'riga',
        countryCode: 'LV',
        cityName: 'Riga',
        timezoneId: 'UTC',
        currencyCode: 'JPY',
        defaultLocaleCode: 'en-US',
        supportedLocaleCodes: ['en-US'],
        centerLat: 56,
        centerLng: 24,
      );
      expect(legacy.timezoneId, 'UTC');
      expect(legacy.currencyCode, 'JPY');
      expect(legacy.defaultLocaleCode, 'en-US');
      expect(legacy.marketCityId, 'riga');
    },
  );
  test('active market is Riga and query defaults are v3', () {
    const MarketConfig market = MarketConfig.riga;
    final DiscoverQuery query = DiscoverQuery.defaults(
      marketCityId: market.marketCityId,
      centerLat: market.centerLat,
      centerLng: market.centerLng,
    );

    expect(query.marketCityId, 'riga');
    expect(query.centerLat, 56.9496);
    expect(query.centerLng, 24.1052);
    expect(query.queryVersion, 3);
  });

  test(
    'legacy automatic Rezekne default migrates but manual area does not',
    () {
      final Map<String, Object?> legacy = <String, Object?>{
        'query_version': 1,
        'market_city_id': 'rezekne',
        'center_lat': 56.5099,
        'center_lng': 27.3332,
        'manual_area_selected': false,
      };
      final DiscoverQuery migrated = DiscoverQueryModel.fromMap(
        legacy,
        defaultMarketCityId: 'riga',
        defaultCenterLat: 56.9496,
        defaultCenterLng: 24.1052,
        legacyCurrencyCode: 'EUR',
      );
      final DiscoverQuery manual = DiscoverQueryModel.fromMap(
        <String, Object?>{...legacy, 'manual_area_selected': true},
        defaultMarketCityId: 'riga',
        defaultCenterLat: 56.9496,
        defaultCenterLng: 24.1052,
        legacyCurrencyCode: 'EUR',
      );

      expect(migrated.marketCityId, 'riga');
      expect(migrated.queryVersion, 3);
      expect(migrated.timeWindow, isNull);
      expect(manual.marketCityId, 'rezekne');
      expect(manual.centerLat, 56.5099);
    },
  );

  test('ranking policy clamps invalid weight and supports kill switch', () {
    expect(const TravelPolicyConfig().effectiveTimeFitWeight, 0.20);
    expect(
      const TravelPolicyConfig(
        timeFitRankingEnabled: false,
      ).effectiveTimeFitWeight,
      0,
    );
    expect(
      const TravelPolicyConfig(timeFitWeight: 0.5).effectiveTimeFitWeight,
      0,
    );
  });

  test('query v3 round-trip preserves time, travel, and Money contracts', () {
    final DiscoverQuery source =
        DiscoverQuery.defaults(
          marketCityId: 'riga',
          centerLat: 56.9496,
          centerLng: 24.1052,
        ).copyWith(
          timeWindow: TimeWindow(
            startAtUtc: DateTime.utc(2026, 7, 20, 10),
            endAtUtc: DateTime.utc(2026, 7, 20, 12),
            timezoneId: 'Europe/Riga',
            mode: TimeWindowMode.flexible,
            flexibilityMinutes: 30,
            resolvedAtUtc: DateTime.utc(2026, 7, 20, 8),
          ),
          travelContext: TravelContext(
            originType: TravelOriginType.manualPin,
            origin: const GeoPoint(latitude: 56.95, longitude: 24.10),
            transportMode: TransportMode.transit,
            includeReturnTrip: false,
          ),
        );

    final DiscoverQuery restored = DiscoverQueryModel.fromMap(
      DiscoverQueryModel.toMap(
        source,
        timezoneRepository: TimezoneRepositoryImpl(),
      ),
      timezoneRepository: TimezoneRepositoryImpl(),
      defaultMarketCityId: 'riga',
      defaultCenterLat: 56.9496,
      defaultCenterLng: 24.1052,
      legacyCurrencyCode: 'EUR',
    );

    expect(restored.queryVersion, 3);
    expect(restored.timeWindow!.mode, TimeWindowMode.flexible);
    expect(
      restored.timeWindow!.effectiveStartAtUtc,
      DateTime.utc(2026, 7, 20, 9, 30),
    );
    expect(
      restored.timeWindow!.effectiveEndAtUtc,
      DateTime.utc(2026, 7, 20, 12, 30),
    );
    expect(restored.travelContext!.transportMode, TransportMode.transit);
    expect(restored.travelContext!.includeReturnTrip, isFalse);
  });
}
