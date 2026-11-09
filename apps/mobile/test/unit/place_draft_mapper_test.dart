import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/place_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';

void main() {
  for (final field in [
    'entryPriceFrom',
    'entryPriceTo',
    'typicalSpendFrom',
    'typicalSpendTo',
  ]) {
    test('Place $field legacy read is exact and current write is integer', () {
      final pricing = <String, Object?>{field: 12.34, 'currencyCode': 'EUR'};
      final json = <String, Object?>{'schemaVersion': 1, 'pricing': pricing};
      final read = PlaceDraftMapper.fromJson(json, defaults: _defaults());
      final wire = PlaceDraftMapper.toJson(read)['pricing'] as Map;
      expect(wire['${field}MinorUnits'], 1234);
      expect(wire.containsKey(field), isFalse);
      pricing['${field}MinorUnits'] = 9;
      expect(
        (PlaceDraftMapper.toJson(
              PlaceDraftMapper.fromJson(json, defaults: _defaults()),
            )['pricing']
            as Map)['${field}MinorUnits'],
        9,
      );
      pricing['${field}MinorUnits'] = 9.5;
      expect(
        () => PlaceDraftMapper.fromJson(json, defaults: _defaults()),
        throwsA(isA<MoneyReadException>()),
      );
      pricing.remove('${field}MinorUnits');
      pricing[field] = 0.001;
      expect(
        () => PlaceDraftMapper.fromJson(json, defaults: _defaults()),
        throwsA(isA<MoneyReadException>()),
      );
    });
  }

  test(
    'round-trips typed Place data and preserves unknown top-level fields',
    () {
      final PlaceDraftData defaults = _defaults();
      final PlaceDraftData decoded = PlaceDraftMapper.fromJson(
        <String, Object?>{
          'schemaVersion': 1,
          'revision': 7,
          'placeKind': 'managedVenue',
          'relationshipToPlace': 'owner',
          'publisherRef': <String, Object?>{'type': 'user', 'id': 'user-1'},
          'contentLocale': 'lv',
          'location': <String, Object?>{
            'marketCityId': 'riga',
            'countryCode': 'LV',
            'city': 'Riga',
            'timezoneId': 'Europe/Riga',
            'latitude': 56.95,
            'longitude': 24.11,
            'pinConfirmed': true,
            'accuracy': 'manual',
          },
          'hours': <String, Object?>{'mode': 'alwaysOpen'},
          'pricing': <String, Object?>{
            'entryType': 'notApplicable',
            'currencyCode': 'EUR',
          },
          'futureField': <String, Object?>{'enabled': true},
        },
        defaults: defaults,
      );

      expect(decoded.revision, 7);
      expect(decoded.placeKind, PlaceKind.managedVenue);
      expect(decoded.contentLocale, 'lv');
      expect(decoded.unknownFields, contains('futureField'));

      final Map<String, Object?> encoded = PlaceDraftMapper.toJson(decoded);
      expect(encoded['futureField'], <String, Object?>{'enabled': true});
      expect(encoded['schemaVersion'], PlaceDraftData.currentSchemaVersion);
    },
  );

  test('rejects unsupported future schema instead of silently downgrading', () {
    expect(
      () => PlaceDraftMapper.fromJson(<String, Object?>{
        'schemaVersion': 999,
      }, defaults: _defaults()),
      throwsFormatException,
    );
  });
}

PlaceDraftData _defaults() => PlaceDraftData.defaults(
  userId: 'user-1',
  marketCityId: 'riga',
  countryCode: 'LV',
  city: 'Riga',
  timezoneId: 'Europe/Riga',
  currencyCode: 'EUR',
);
