import '../../../core/geo/geo_bounds.dart';
import '../../../core/map/map_scene.dart';
import '../domain/entities/route_draft_data.dart';
import 'route_create_coordinator.dart';

typedef RouteCreateRuntimeFactory = Future<RouteCreateRuntime> Function();

class RouteCreateRuntime {
  RouteCreateRuntime({
    required this.coordinator,
    required this.coverageBounds,
    required Iterable<MapPolylineData> graphEdges,
    required this.supportedProfiles,
    required this.attribution,
  }) : graphEdges = List<MapPolylineData>.unmodifiable(graphEdges);

  final RouteCreateCoordinator coordinator;
  final GeoBounds coverageBounds;
  final List<MapPolylineData> graphEdges;
  final List<RouteProfileRef> supportedProfiles;
  final String attribution;
}
