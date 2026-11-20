import 'package:recharge/app/config/catalog_market_binding.dart';
import 'package:recharge/shared/primitives/market/market_ref.dart';
import 'package:recharge/features/create/data/models/scenario_draft_mapper.dart';
import 'package:recharge/features/discover/data/models/discover_query_model.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/time/utc_instant.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/models/rental_draft_mapper.dart';
import 'package:recharge/features/create/data/models/place_draft_mapper.dart';
import 'package:recharge/features/create/data/models/find_people_draft_mapper.dart';
import 'package:recharge/features/create/data/models/collection_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';

void main() {
  test('AC-34 Catalog binding is explicit and unknown markets fail closed', () {
    expect(catalogMarketIdFor(MarketRef.riga), 'LV');
    expect(
      () => catalogMarketIdFor(MarketRef.parse('unknown-market')),
      throwsFormatException,
    );
  });
  test('AC-34 stored Scenario without configuration stays incomplete', () {
    final draft = ScenarioDraftMapper.fromJson({});
    expect(draft.defaultTimezoneId, isEmpty);
    expect(draft.displayCurrencyCode, isEmpty);
  });
  test(
    'AC-34 current Discover money cannot inherit legacy currency context',
    () {
      final raw = <String, Object?>{
        'query_version': 3,
        'budget_min_minor_units': 1500,
      };
      expect(
        () => DiscoverQueryModel.fromMap(
          raw,
          defaultMarketCityId: 'riga',
          defaultCenterLat: 56,
          defaultCenterLng: 24,
          legacyCurrencyCode: 'EUR',
        ),
        throwsA(isA<MoneyReadException>()),
      );
    },
  );
  final rental = RentalDraftData.defaults(
    userId: 'u',
    currencyCode: 'EUR',
    timeZoneId: 'Europe/Riga',
  );
  final place = PlaceDraftData.defaults(
    userId: 'u',
    marketCityId: 'riga',
    countryCode: 'LV',
    city: 'Riga',
    timezoneId: 'Europe/Riga',
    currencyCode: 'EUR',
  );
  final people = FindPeopleDraftData.defaults(userId: 'u', currencyCode: 'EUR');
  final collection = CollectionDraftData.defaults(
    publisherRef: const PublisherRef(type: PublisherType.user, id: 'u'),
  );
  test(
    'AC-34/35 malformed nested currency is never replaced with EUR context',
    () {
      for (final value in <Object?>[123, null, '']) {
        expect(
          () => PlaceDraftMapper.fromJson({
            'pricing': {
              'entryPriceFromMinorUnits': 1500,
              'currencyCode': value,
            },
          }, defaults: place),
          throwsA(isA<MoneyReadException>()),
        );
        expect(
          () => FindPeopleDraftMapper.fromJson({
            'expectedSpendAmountMinorUnits': 1500,
            'currencyCode': value,
          }, defaults: people),
          throwsA(isA<MoneyReadException>()),
        );
      }
    },
  );
  test(
    'AC-35 restored currency subtotals never truncate fractional minor units',
    () {
      expect(
        () => ScenarioDraftMapper.fromJson({
          'totals': {
            'originalCurrencySubtotals': [
              {
                'currencyCode': 'EUR',
                'knownMinorUnits': 1.5,
                'estimatedMinorUnits': 0,
              },
            ],
          },
        }),
        throwsA(isA<MoneyReadException>()),
      );
    },
  );
  test(
    'AC-34/35 present malformed Place/Rental identity never inherits parent context',
    () {
      for (final field in ['marketCityId', 'timezoneId']) {
        expect(
          () => PlaceDraftMapper.fromJson({
            'location': {field: 123},
          }, defaults: place),
          throwsFormatException,
        );
        final restored = PlaceDraftMapper.fromJson({
          'location': {field: null},
        }, defaults: place);
        expect(
          field == 'timezoneId'
              ? restored.location.timezoneId
              : restored.location.marketCityId,
          isEmpty,
        );
      }
      expect(
        () => RentalDraftMapper.fromJson({
          'availability': {'timeZoneId': 123},
        }, defaults: rental),
        throwsFormatException,
      );
      expect(
        RentalDraftMapper.fromJson({
          'availability': {'timeZoneId': null},
        }, defaults: rental).availability.timeZoneId,
        isEmpty,
      );
    },
  );
  final readers = <String, Object Function(String)>{
    'Rental': (s) => RentalDraftMapper.fromJson({
      'attestation': {'acceptedAtUtc': s},
    }, defaults: rental),
    'Place': (s) => PlaceDraftMapper.fromJson({
      'provenance': {'createdAtUtc': s},
    }, defaults: place),
    'FindPeople': (s) =>
        FindPeopleDraftMapper.fromJson({'seriesEndAtUtc': s}, defaults: people),
    'Collection': (s) => CollectionDraftMapper.fromJson({
      'composition_review': {'draft_revision': 1, 'reviewed_at_utc': s},
    }, defaults: collection),
  };
  for (final reader in readers.entries) {
    test(
      'AC-29/35 ${reader.key}: UTC precision roundtrip and malformed input refusal without source mutation',
      () {
        const valid = '2026-11-20T12:34:56.123456Z';
        final restored = reader.value(valid);
        final encoded = switch (restored) {
          RentalDraftData value => RentalDraftMapper.toJson(value),
          PlaceDraftData value => PlaceDraftMapper.toJson(value),
          FindPeopleDraftData value => FindPeopleDraftMapper.toJson(value),
          CollectionDraftData value => CollectionDraftMapper.toJson(value),
          _ => throw StateError('unexpected mapper result'),
        };
        expect(jsonEncode(encoded), contains(valid));
        for (final invalid in [
          '2026-11-20T12:34:56',
          '2026-11-20T12:34:56+02:00',
          '2026-02-30T12:00:00Z',
          '2026-11-20T24:00:00Z',
          '2026-11-20T12:34:56.1234567Z',
        ]) {
          expect(
            () => reader.value(invalid),
            throwsFormatException,
            reason: invalid,
          );
        }
      },
    );
  }
  test(
    'AC-34/36 stored identities and instants do not follow a new active configuration',
    () {
      final source = CreateDraftModel.fromEntity(
        CreateDraftEntity.defaults(
          organizerId: 'u',
          organizerEmail: '',
          organizerName: '',
          marketCityId: 'explicit-market',
          timezone: 'Pacific/Honolulu',
          currency: 'USD',
        ),
      ).toJson();
      final before = jsonEncode(source);
      final restored = CreateDraftModel.fromJson(
        source,
        activeMarketCityId: 'riga',
        activeTimezone: 'Europe/Riga',
        activeCurrency: 'EUR',
        activeCity: 'Riga',
        activeCountry: 'LV',
      );
      expect(restored.marketCityId, 'explicit-market');
      expect(restored.timezone, 'Pacific/Honolulu');
      expect(restored.currency, 'USD');
      expect(jsonEncode(source), before);
      source.remove('currency');
      source.remove('timezone');
      source.remove('marketCityId');
      final incomplete = CreateDraftModel.fromJson(
        source,
        activeMarketCityId: 'riga',
        activeTimezone: 'Europe/Riga',
        activeCurrency: 'EUR',
      );
      expect(incomplete.marketCityId, isEmpty);
      expect(incomplete.timezone, isEmpty);
      expect(incomplete.currency, isEmpty);
    },
  );
  test('AC-35 strict optional UTC reader never normalizes invalid fields', () {
    expect(UtcInstant.tryParse('2026-02-30T00:00:00Z'), isNull);
    expect(
      UtcInstant.tryParse('2026-11-20T01:02:03.123456Z')!.value.microsecond,
      456,
    );
    expect(UtcInstant.tryParse(' 2026-11-20T01:02:03Z '), isNull);
  });
}
