import '../entities/route_publication_data.dart';

abstract interface class RoutePublicationIndexSink {
  Future<void> activate(PublishedRouteVersion version);

  Future<void> archive(String routeId);
}
