import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'package:recharge/features/favorites/presentation/pages/favorites_page.dart';

void main() {
  testWidgets('shows empty state when favorites list is empty', (tester) async {
    final controller = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(_FakeFavoritesRepository()),
      addFavoriteUseCase: AddFavoriteUseCase(_FakeFavoritesRepository()),
      removeFavoriteUseCase: RemoveFavoriteUseCase(_FakeFavoritesRepository()),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          favoritesControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пока нет сохраненных событий'), findsOneWidget);
  });

  testWidgets('renders favorites item in list', (tester) async {
    final repository = _FakeFavoritesRepository(
      initial: <FavoriteItemEntity>[
        _favorite('evt_1', 'Утренняя йога'),
      ],
    );
    final controller = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(repository),
      addFavoriteUseCase: AddFavoriteUseCase(repository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          favoritesControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Утренняя йога'), findsOneWidget);
  });
}

FavoriteItemEntity _favorite(String id, String title) {
  return FavoriteItemEntity(
    id: id,
    title: title,
    subtitle: 'Subtitle',
    city: 'Rezekne',
    category: 'wellness',
    startsAtUtc: DateTime.parse('2026-04-20T10:00:00Z'),
    distanceKm: 1.8,
    priceAmount: 0,
    isFree: true,
    savedAtUtc: DateTime.parse('2026-04-20T08:00:00Z'),
  );
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeFavoritesRepository implements FavoritesRepository {
  _FakeFavoritesRepository({List<FavoriteItemEntity>? initial})
      : _storage = initial == null
            ? <FavoriteItemEntity>[]
            : List<FavoriteItemEntity>.from(initial);

  final List<FavoriteItemEntity> _storage;

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {
    _storage.removeWhere((FavoriteItemEntity element) => element.id == item.id);
    _storage.insert(0, item);
  }

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async {
    return List<FavoriteItemEntity>.from(_storage);
  }

  @override
  Future<void> removeFavorite(String itemId) async {
    _storage.removeWhere((FavoriteItemEntity element) => element.id == itemId);
  }
}
