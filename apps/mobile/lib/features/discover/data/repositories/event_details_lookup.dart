import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/published_event_discovery_entity.dart';
import '../../domain/repositories/details_lookup_port.dart';
import '../../domain/repositories/published_event_discovery_port.dart';

/// [DetailsLookupPort] wrapping [PublishedEventDiscoveryPort] — serves
/// `CatalogObjectType.event` only (`DTL-EVT-01` §3), by the same shape as
/// `RentalDetailsLookup`.
class EventDetailsLookup implements DetailsLookupPort {
  const EventDetailsLookup(this._port);

  final PublishedEventDiscoveryPort _port;

  @override
  Future<PublishedEventDiscoveryEntity?> lookup(String objectId) {
    return _port.getActiveEvent(objectId);
  }

  @override
  CatalogObjectType classify(Object projection) => CatalogObjectType.event;
}
