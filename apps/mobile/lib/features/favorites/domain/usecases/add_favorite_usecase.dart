import '../entities/favorite_item_entity.dart';
import '../repositories/favorites_repository.dart';

class AddFavoriteUseCase {
  AddFavoriteUseCase(this._repository);

  final FavoritesRepository _repository;

  Future<void> call(FavoriteItemEntity item) {
    return _repository.addFavorite(item);
  }
}
