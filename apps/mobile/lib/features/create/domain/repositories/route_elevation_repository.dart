import '../../../../core/geo/geo_point.dart';
import '../entities/route_draft_data.dart';

enum RouteElevationCompleteness { complete, partial, unavailable }

class RouteElevationRequest {
  RouteElevationRequest({
    required this.operationId,
    required this.expectedGeometryRevision,
    required this.requestFingerprint,
    required this.geometryHash,
    required Iterable<GeoPoint> points,
  }) : points = List<GeoPoint>.unmodifiable(points);

  final String operationId;
  final int expectedGeometryRevision;
  final String requestFingerprint;
  final String geometryHash;
  final List<GeoPoint> points;
}

class RouteElevationSample {
  const RouteElevationSample({
    required this.pointIndex,
    required this.distanceFromStartMeters,
    required this.elevationMeters,
  });

  final int pointIndex;
  final double distanceFromStartMeters;
  final double elevationMeters;
}

class RouteElevationResult {
  RouteElevationResult({
    required this.operationId,
    required this.expectedGeometryRevision,
    required this.requestFingerprint,
    required this.geometryHash,
    required this.completeness,
    required Iterable<RouteElevationSample> samples,
    required this.provenance,
  }) : samples = List<RouteElevationSample>.unmodifiable(samples);

  final String operationId;
  final int expectedGeometryRevision;
  final String requestFingerprint;
  final String geometryHash;
  final RouteElevationCompleteness completeness;
  final List<RouteElevationSample> samples;
  final RouteProvenanceDraft provenance;
}

abstract interface class RouteElevationRepository {
  Future<RouteElevationResult> resolve(RouteElevationRequest request);
}
