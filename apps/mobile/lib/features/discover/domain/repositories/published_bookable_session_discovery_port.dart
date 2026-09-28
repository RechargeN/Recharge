import '../entities/published_bookable_session_discovery_entity.dart';

abstract interface class PublishedBookableSessionDiscoveryPort {
  Future<PublishedBookableSessionDiscoveryEntity?> getActiveBookableSession(
    String sessionId,
  );
}
