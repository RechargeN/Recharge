import '../entities/favorite_item_entity.dart';

abstract class FavoritesRepository {
  Future<List<FavoriteItemEntity>> getFavorites();
  Future<void> addFavorite(FavoriteItemEntity item);
  Future<void> removeFavorite(String itemId);
}
