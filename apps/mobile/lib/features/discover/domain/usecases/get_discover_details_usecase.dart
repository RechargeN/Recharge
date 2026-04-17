import '../entities/discover_item_entity.dart';
import '../repositories/discover_repository.dart';

class GetDiscoverDetailsUseCase {
  GetDiscoverDetailsUseCase(this._repository);

  final DiscoverRepository _repository;

  Future<DiscoverItemEntity> call(String itemId) {
    return _repository.getDetails(itemId);
  }
}

