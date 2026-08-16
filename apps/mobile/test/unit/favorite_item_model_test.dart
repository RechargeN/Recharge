import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/favorites/data/models/favorite_item_model.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';

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
        });

    expect(model.toEntity().targetRoute, isNull);
    expect(model.toEntity().coverImageUrl, isEmpty);
  });

  test('keeps legacy raw Scenario target readable', () {
    final FavoriteItemEntity entity = FavoriteItemEntity(
      id: 'scenario_1',
      title: 'Scenario',
      subtitle: '2 stops',
      city: 'Rezekne',
      category: 'scenario',
      startsAtUtc: DateTime.parse('2026-04-20T10:00:00Z'),
      distanceKm: 2.4,
      priceAmount: 0,
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
  });

  test('round-trips a typed Quick Plan target with stable id', () {
    final entity = FavoriteItemEntity(
      id: 'favorite-1',
      title: 'Quick Plan',
      subtitle: '2 stops',
      city: 'Riga',
      category: 'quick_plan',
      startsAtUtc: DateTime.utc(2026, 8, 10),
      distanceKm: 2,
      priceAmount: 0,
      isFree: true,
      savedAtUtc: DateTime.utc(2026, 8, 10),
      targetRoute: '/quick-plan/01J5QP00000000000000000000',
      planningTargetKind: FavoritePlanningTargetKind.quickPlan,
      planningTargetId: '01J5QP00000000000000000000',
    );

    final restored = FavoriteItemModel.fromEntity(entity).toEntity();
    expect(restored.planningTargetKind, FavoritePlanningTargetKind.quickPlan);
    expect(restored.planningTargetId, '01J5QP00000000000000000000');
  });
}
