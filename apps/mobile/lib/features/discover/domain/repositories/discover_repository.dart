import '../entities/discover_item_entity.dart';
import '../entities/discover_query.dart';

abstract class DiscoverRepository {
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query);
  Future<DiscoverItemEntity> getDetails(String itemId);
}

/// L4.5: a typed Discover failure. The UI turns [code] into text; [message]
/// is an optional developer note and is never shown.
class DiscoverException implements Exception {
  const DiscoverException({required this.code, this.message = ''});

  final String code;
  final String message;
}

/// DTL-RTE-02 RD-07/RD-08: Details failures that are not "not found". A lost
/// connection and a Route revision newer than the listing are shown with a
/// retry instead of as an unavailable object.
const String routeRevisionChangedCode = 'CATALOG_ROUTE_REVISION_CHANGED';

bool isRetryableDetailsFailure(DiscoverException error) =>
    error.code == routeRevisionChangedCode ||
    error.code.startsWith('CATALOG_TRANSPORT_');
