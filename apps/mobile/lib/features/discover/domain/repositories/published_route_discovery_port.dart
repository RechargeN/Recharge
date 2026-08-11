import '../entities/published_route_discovery_entity.dart';

abstract interface class PublishedRouteDiscoveryPort {
  Future<List<PublishedRouteDiscoveryEntity>> loadActiveRoutes();

  Future<PublishedRouteDiscoveryEntity?> getActiveRoute(String routeId);
}
