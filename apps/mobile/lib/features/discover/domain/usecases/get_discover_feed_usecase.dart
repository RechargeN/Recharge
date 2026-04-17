import '../../application/queries/discover_query.dart';
import '../entities/discover_item_entity.dart';
import '../repositories/discover_repository.dart';

class GetDiscoverFeedUseCase {
  GetDiscoverFeedUseCase(this._repository);

  final DiscoverRepository _repository;

  Future<List<DiscoverItemEntity>> call(DiscoverQuery query) {
    return _repository.getFeed(query);
  }
}
