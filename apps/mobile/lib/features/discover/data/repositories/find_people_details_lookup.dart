import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/published_find_people_discovery_entity.dart';
import '../../domain/repositories/details_lookup_port.dart';
import '../../domain/repositories/published_find_people_discovery_port.dart';

class FindPeopleDetailsLookup implements DetailsLookupPort {
  const FindPeopleDetailsLookup(this._port);

  final PublishedFindPeopleDiscoveryPort _port;

  @override
  Future<PublishedFindPeopleDiscoveryEntity?> lookup(String objectId) {
    return _port.getActiveFindPeopleRequest(objectId);
  }

  @override
  CatalogObjectType classify(Object projection) => CatalogObjectType.findPeople;
}
