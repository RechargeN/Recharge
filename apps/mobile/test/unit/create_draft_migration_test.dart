import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('legacy broken Latvia default migrates to Riga market and timezone', () {
    final CreateDraftModel model = CreateDraftModel.fromJson(
      <String, dynamic>{
        'id': 'draft_1',
        'objectType': 'event',
        'country': 'Latvia',
        'city': '',
        'timezone': 'Europe/Moscow',
      },
      activeCurrency: 'EUR',
      activeMarketCityId: 'riga',
      activeTimezone: 'Europe/Riga',
      activeCountry: 'LV',
      activeCity: 'Riga',
    );

    expect(model.schemaVersion, 9);
    expect(model.marketCityId, 'riga');
    expect(model.timezone, 'Europe/Riga');
    expect(model.toJson()['schemaVersion'], 9);
  });

  test('legacy Rezekne remains legacy market with Riga timezone', () {
    final CreateDraftModel model = CreateDraftModel.fromJson(
      <String, dynamic>{
        'id': 'draft_2',
        'objectType': 'place',
        'country': 'Latvia',
        'city': 'Rezekne',
        'timezone': 'Europe/Moscow',
      },
      activeCurrency: 'EUR',
      activeMarketCityId: 'riga',
      activeTimezone: 'Europe/Riga',
      activeCountry: 'LV',
      activeCity: 'Riga',
    );

    expect(model.marketCityId, 'rezekne');
    expect(model.timezone, 'Europe/Riga');
  });

  test('unknown legacy location is not overwritten', () {
    final CreateDraftModel model = CreateDraftModel.fromJson(
      <String, dynamic>{
        'id': 'draft_3',
        'objectType': 'place',
        'country': 'Estonia',
        'city': 'Tartu',
        'timezone': 'Europe/Tallinn',
      },
      activeCurrency: 'EUR',
      activeMarketCityId: 'riga',
      activeTimezone: 'Europe/Riga',
      activeCountry: 'LV',
      activeCity: 'Riga',
    );

    expect(model.marketCityId, isEmpty);
    expect(model.timezone, 'Europe/Tallinn');
  });

  test('schema v9 preserves published Route version lineage', () {
    final draft = CreateDraftEntity.defaults(
      organizerId: 'creator-1',
      organizerEmail: 'creator@example.com',
      organizerName: 'Creator',
    ).copyWith(basedOnPublishedVersionId: 'version-42');

    final restored = CreateDraftModel.fromJson(
      CreateDraftModel.fromEntity(draft).toJson(),
      activeCurrency: 'EUR',
    ).toEntity();

    expect(restored.basedOnPublishedVersionId, 'version-42');
  });

  test(
    'schema v9 writes canonical base price and rejects fractional units',
    () {
      final CreateDraftEntity draft =
          CreateDraftEntity.defaults(
            organizerId: 'creator-1',
            organizerEmail: 'creator@example.com',
            organizerName: 'Creator',
            currency: 'EUR',
          ).copyWith(
            isFree: false,
            basePrice: const Money(
              minorUnits: 1599,
              currency: CurrencyCode.eur,
            ),
          );
      final Map<String, dynamic> encoded = CreateDraftModel.fromEntity(
        draft,
      ).toJson();

      expect(encoded['basePriceMinorUnits'], 1599);
      expect(encoded, isNot(contains('basePrice')));
      expect(
        () => CreateDraftModel.fromJson(<String, dynamic>{
          ...encoded,
          'basePriceMinorUnits': 15.99,
        }, activeCurrency: 'EUR'),
        throwsFormatException,
      );
    },
  );
}
