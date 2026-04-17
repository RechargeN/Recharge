import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/state/favorites_state.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';

void main() {
  late _FakeFavoritesRepository repository;
  late FavoritesController controller;

  setUp(() {
    repository = _FakeFavoritesRepository();
    controller = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(repository),
      addFavoriteUseCase: AddFavoriteUseCase(repository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );
  });

  test('loadFavorites -> ready with empty list', () async {
    await controller.loadFavorites();

    expect(controller.state.status, FavoritesStatus.ready);
    expect(controller.state.items, isEmpty);
  });

  test('addFavorite -> item persisted in state', () async {
    final item = _favorite('evt_1');

    await controller.addFavorite(item, sourceScreen: 'test');

    expect(controller.state.items, hasLength(1));
    expect(controller.isFavorite('evt_1'), isTrue);
  });

  test('toggleFavorite -> removes existing item', () async {
    final item = _favorite('evt_1');
    await controller.addFavorite(item, sourceScreen: 'test');

    await controller.toggleFavorite(item, sourceScreen: 'test');

    expect(controller.state.items, isEmpty);
    expect(controller.isFavorite('evt_1'), isFalse);
  });
}

FavoriteItemEntity _favorite(String id) {
  return FavoriteItemEntity(
    id: id,
    title: 'Title',
    subtitle: 'Subtitle',
    city: 'Rezekne',
    category: 'outdoor',
    startsAtUtc: DateTime.parse('2026-04-20T10:00:00Z'),
    distanceKm: 2.4,
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
  final List<FavoriteItemEntity> _storage = <FavoriteItemEntity>[];

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {
    _storage.removeWhere((FavoriteItemEntity element) => element.id == item.id);
    _storage.insert(0, item.copyWith(savedAtUtc: DateTime.now().toUtc()));
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
