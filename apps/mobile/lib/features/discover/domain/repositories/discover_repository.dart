import '../entities/discover_item_entity.dart';

abstract class DiscoverRepository {
  Future<List<DiscoverItemEntity>> getFeed();
  Future<DiscoverItemEntity> getDetails(String itemId);
}

class DiscoverException implements Exception {
  const DiscoverException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

