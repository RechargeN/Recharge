import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/published_rental_discovery_entity.dart';
import '../../domain/repositories/details_lookup_port.dart';
import '../../domain/repositories/published_rental_discovery_port.dart';

/// [DetailsLookupPort] wrapping the already-existing
/// `PublishedRentalDiscoveryPort` — serves `CatalogObjectType.rental` only
/// (`DTL-OBJ-01` §4).
class RentalDetailsLookup implements DetailsLookupPort {
  const RentalDetailsLookup(this._port);

  final PublishedRentalDiscoveryPort _port;

  @override
  Future<PublishedRentalDiscoveryEntity?> lookup(String objectId) {
    return _port.getActiveRental(objectId);
  }

  @override
  CatalogObjectType classify(Object projection) => CatalogObjectType.rental;
}
