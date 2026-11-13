import '../entities/published_class_workshop_discovery_entity.dart';

abstract interface class PublishedClassWorkshopDiscoveryPort {
  Future<PublishedClassWorkshopDiscoveryEntity?> getActiveClassWorkshop(
    String offeringId,
  );
}
