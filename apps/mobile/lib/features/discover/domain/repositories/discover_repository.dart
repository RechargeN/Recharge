import '../entities/discover_item_entity.dart';
import '../entities/discover_query.dart';

abstract class DiscoverRepository {
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query);
  Future<DiscoverItemEntity> getDetails(String itemId);
}

class DiscoverException implements Exception {
  const DiscoverException({required this.code, required this.message});

  final String code;
  final String message;
}
