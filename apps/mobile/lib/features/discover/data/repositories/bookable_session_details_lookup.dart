import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/published_bookable_session_discovery_entity.dart';
import '../../domain/repositories/details_lookup_port.dart';
import '../../domain/repositories/published_bookable_session_discovery_port.dart';

class BookableSessionDetailsLookup implements DetailsLookupPort {
  const BookableSessionDetailsLookup(this._port);

  final PublishedBookableSessionDiscoveryPort _port;

  @override
  Future<PublishedBookableSessionDiscoveryEntity?> lookup(
    String objectId,
  ) async {
    final projection = await _port.getActiveBookableSession(objectId);
    return projection?.sessionId == objectId ? projection : null;
  }

  @override
  CatalogObjectType classify(Object projection) => CatalogObjectType.session;
}
