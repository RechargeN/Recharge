import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/favorites/data/models/favorite_item_model.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('fromJson supports older favorites without targetRoute', () {
    final FavoriteItemModel model =
        FavoriteItemModel.fromJson(<String, dynamic>{
          'id': 'evt_1',
          'title': 'Title',
          'subtitle': 'Subtitle',
          'city': 'Rezekne',
          'category': 'wellness',
          'startsAtUtcIso': '2026-04-20T10:00:00.000Z',
          'distanceKm': 1.2,
          'priceAmount': 0,
          'isFree': true,
          'savedAtUtcIso': '2026-04-20T08:00:00.000Z',
        }, legacyCurrency: CurrencyCode.eur);

    expect(model.toEntity().targetRoute, isNull);
    expect(model.toEntity().coverImageUrl, isEmpty);
  });

  test('roundtrips targetRoute for saved scenarios', () {
    final FavoriteItemEntity entity = FavoriteItemEntity(
      id: 'scenario_1',
      title: 'Scenario',
      subtitle: '2 stops',
      city: 'Rezekne',
      category: 'scenario',
      startsAtUtc: DateTime.parse('2026-04-20T10:00:00Z'),
      distanceKm: 2.4,
      price: const Money.zero(CurrencyCode.eur),
      isFree: true,
      savedAtUtc: DateTime.parse('2026-04-20T08:00:00Z'),
      targetRoute: '/scenario-builder?mood=calm&steps=a,b',
      coverImageUrl: 'https://images.example/route.jpg',
    );

    final FavoriteItemEntity restored = FavoriteItemModel.fromEntity(
      entity,
    ).toEntity();

    expect(restored.targetRoute, entity.targetRoute);
    expect(restored.coverImageUrl, entity.coverImageUrl);
    expect(
      FavoriteItemModel.fromEntity(entity).toJson(),
      containsPair('priceMinorUnits', 0),
    );
    expect(
      FavoriteItemModel.fromEntity(entity).toJson(),
      isNot(contains('priceAmount')),
    );
  });

  test('fractional canonical minor units fail closed', () {
    expect(
      () => FavoriteItemModel.fromJson(<String, dynamic>{
        'id': 'evt_invalid',
        'title': 'Invalid',
        'subtitle': 'Invalid',
        'city': 'Riga',
        'category': 'other',
        'startsAtUtcIso': '2026-04-20T10:00:00.000Z',
        'distanceKm': 1.2,
        'priceMinorUnits': 12.5,
        'currencyCode': 'EUR',
        'isFree': false,
        'savedAtUtcIso': '2026-04-20T08:00:00.000Z',
      }, legacyCurrency: CurrencyCode.eur),
      throwsFormatException,
    );
  });
}
