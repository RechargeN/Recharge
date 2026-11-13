import '../entities/published_find_people_discovery_entity.dart';

/// Read side for active public Find People Details (`DTL-FP-01` §6).
abstract interface class PublishedFindPeopleDiscoveryPort {
  Future<PublishedFindPeopleDiscoveryEntity?> getActiveFindPeopleRequest(
    String requestId,
  );
}
