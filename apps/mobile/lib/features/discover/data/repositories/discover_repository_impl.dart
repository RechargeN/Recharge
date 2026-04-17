import '../../domain/entities/discover_item_entity.dart';
import '../../domain/repositories/discover_repository.dart';
import '../datasources/discover_remote_datasource.dart';

class DiscoverRepositoryImpl implements DiscoverRepository {
  DiscoverRepositoryImpl({
    required DiscoverRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final DiscoverRemoteDataSource _remoteDataSource;

  @override
  Future<List<DiscoverItemEntity>> getFeed() {
    return _remoteDataSource.getFeed();
  }

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) {
    return _remoteDataSource.getDetails(itemId);
  }
}

