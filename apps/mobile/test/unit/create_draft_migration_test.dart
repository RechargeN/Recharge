import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';

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
      activeMarketCityId: 'riga',
      activeTimezone: 'Europe/Riga',
      activeCountry: 'LV',
      activeCity: 'Riga',
    );

    expect(model.schemaVersion, 2);
    expect(model.marketCityId, 'riga');
    expect(model.timezone, 'Europe/Riga');
    expect(model.toJson()['schemaVersion'], 2);
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
      activeMarketCityId: 'riga',
      activeTimezone: 'Europe/Riga',
      activeCountry: 'LV',
      activeCity: 'Riga',
    );

    expect(model.marketCityId, isEmpty);
    expect(model.timezone, 'Europe/Tallinn');
  });
}
