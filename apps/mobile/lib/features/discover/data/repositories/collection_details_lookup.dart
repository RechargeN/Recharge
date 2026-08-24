import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/published_collection_discovery_entity.dart';
import '../../domain/repositories/details_lookup_port.dart';
import '../../domain/repositories/published_collection_discovery_port.dart';

/// [DetailsLookupPort] wrapping the already-existing
/// `PublishedCollectionDiscoveryPort` — serves `CatalogObjectType.collection`
/// only (`DTL-LINK-01` §1.1.2).
class CollectionDetailsLookup implements DetailsLookupPort {
  const CollectionDetailsLookup(this._port);

  final PublishedCollectionDiscoveryPort _port;

  @override
  Future<PublishedCollectionDiscoveryEntity?> lookup(String objectId) {
    return _port.getActiveCollection(objectId);
  }

  @override
  CatalogObjectType classify(Object projection) => CatalogObjectType.collection;
}
