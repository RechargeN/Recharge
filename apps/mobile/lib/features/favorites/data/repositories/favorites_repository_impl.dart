import '../../domain/entities/favorite_item_entity.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_local_datasource.dart';
import '../models/favorite_item_model.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl({
    required FavoritesLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final FavoritesLocalDataSource _localDataSource;

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async {
    final List<FavoriteItemModel> items = await _localDataSource.readFavorites();
    final List<FavoriteItemEntity> entities =
        items.map((FavoriteItemModel item) => item.toEntity()).toList(growable: false);
    entities.sort((FavoriteItemEntity a, FavoriteItemEntity b) {
      return b.savedAtUtc.compareTo(a.savedAtUtc);
    });
    return entities;
  }

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {
    final List<FavoriteItemModel> current = await _localDataSource.readFavorites();
    final List<FavoriteItemModel> filtered = current
        .where((FavoriteItemModel element) => element.id != item.id)
        .toList(growable: true);
    filtered.insert(
      0,
      FavoriteItemModel.fromEntity(
        item.copyWith(savedAtUtc: DateTime.now().toUtc()),
      ),
    );
    await _localDataSource.writeFavorites(filtered);
  }

  @override
  Future<void> removeFavorite(String itemId) async {
    final List<FavoriteItemModel> current = await _localDataSource.readFavorites();
    final List<FavoriteItemModel> filtered = current
        .where((FavoriteItemModel element) => element.id != itemId)
        .toList(growable: false);
    await _localDataSource.writeFavorites(filtered);
  }
}
