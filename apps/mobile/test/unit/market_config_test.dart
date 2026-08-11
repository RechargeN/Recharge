import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/app/config/travel_policy_config.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/geo_point.dart';
import 'package:recharge/features/discover/domain/entities/time_window.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('active market is Riga and query defaults are v3', () {
    const MarketConfig market = MarketConfig.riga;
    final DiscoverQuery query = DiscoverQuery.defaults(
      marketCityId: market.marketCityId,
      centerLat: market.centerLat,
      centerLng: market.centerLng,
      currency: CurrencyCode.parse(market.currencyCode),
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
      final DiscoverQuery migrated = DiscoverQuery.fromMap(
        legacy,
        defaultMarketCityId: 'riga',
        defaultCenterLat: 56.9496,
        defaultCenterLng: 24.1052,
        defaultCurrency: CurrencyCode.eur,
      );
      final DiscoverQuery manual = DiscoverQuery.fromMap(
        <String, Object?>{...legacy, 'manual_area_selected': true},
        defaultMarketCityId: 'riga',
        defaultCenterLat: 56.9496,
        defaultCenterLng: 24.1052,
        defaultCurrency: CurrencyCode.eur,
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

  test('query v3 round-trip preserves time and travel contracts', () {
    final DiscoverQuery source =
        DiscoverQuery.defaults(
          marketCityId: 'riga',
          centerLat: 56.9496,
          centerLng: 24.1052,
        ).copyWith(
          budgetMax: const Money(
            minorUnits: 1234,
            currency: CurrencyCode.eur,
          ),
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

    final Map<String, Object?> encoded = source.toMap();
    final DiscoverQuery restored = DiscoverQuery.fromMap(
      encoded,
      defaultMarketCityId: 'riga',
      defaultCenterLat: 56.9496,
      defaultCenterLng: 24.1052,
      defaultCurrency: CurrencyCode.eur,
    );

    expect(restored.queryVersion, 3);
    expect(encoded['budget_max_minor_units'], 1234);
    expect(encoded, isNot(contains('budget_max')));
    expect(
      () => DiscoverQuery.fromMap(
        <String, Object?>{
          ...encoded,
          'budget_max_minor_units': 12.5,
        },
        defaultMarketCityId: 'riga',
        defaultCenterLat: 56.9496,
        defaultCenterLng: 24.1052,
        defaultCurrency: CurrencyCode.eur,
      ),
      throwsFormatException,
    );
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
