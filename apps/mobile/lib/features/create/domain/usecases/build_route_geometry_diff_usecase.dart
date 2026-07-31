import '../../../../core/geo/geo_point.dart';
import '../entities/route_draft_data.dart';
import '../entities/route_quality_workflow_data.dart';
import '../entities/route_publication_data.dart';
import '../repositories/route_geometry_diff_builder.dart';

class BuildRouteGeometryDiffUseCase implements RouteGeometryDiffBuilder {
  const BuildRouteGeometryDiffUseCase();

  @override
  RouteGeometryDiff build({
    required PublishedRouteVersion baseVersion,
    required RouteDraftData candidate,
  }) {
    final points = <GeoPoint>[];
    for (final segment in candidate.orderedSegments) {
      if (points.isEmpty) {
        points.addAll(segment.geometry.points);
      } else if (points.last == segment.geometry.points.first) {
        points.addAll(segment.geometry.points.skip(1));
      } else {
        throw StateError('Candidate Route geometry is disconnected.');
      }
    }
    if (points.length < 2) {
      throw StateError('Candidate Route geometry is too short.');
    }
    final candidateGeometry = RouteGeometryDraft.fromPoints(
      points,
      encodingPolicy: candidate.encodingPolicy,
    );
    final baseRoute = baseVersion.contentSnapshot.routeData;
    if (baseRoute == null) {
      throw StateError('Published Route content snapshot is missing.');
    }
    return RouteGeometryDiff(
      baseGeometryHash: baseVersion.geometryHash,
      candidateGeometryHash: candidateGeometry.geometryHash,
      basePointCount: baseRoute.geometryPointCount,
      candidatePointCount: candidate.geometryPointCount,
      distanceDeltaMeters:
          candidate.metrics.distanceMeters -
          baseVersion.projection.distanceMeters,
      anchorCountDelta: candidate.anchors.length - baseRoute.anchors.length,
      waypointCountDelta:
          candidate.waypoints.length - baseRoute.waypoints.length,
    );
  }
}
