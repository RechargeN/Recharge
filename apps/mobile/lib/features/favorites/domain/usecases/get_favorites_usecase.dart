import '../entities/favorite_item_entity.dart';
import '../repositories/favorites_repository.dart';

class GetFavoritesUseCase {
  GetFavoritesUseCase(this._repository);

  final FavoritesRepository _repository;

  Future<List<FavoriteItemEntity>> call() {
    return _repository.getFavorites();
  }
}
