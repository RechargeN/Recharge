import '../../../../core/geo/geo_point.dart';
import '../entities/route_draft_data.dart';

abstract interface class RouteCancellationSignal {
  bool get isCancelled;
}

class RouteRoutingException implements Exception {
  const RouteRoutingException({
    required this.code,
    required this.operationId,
    required this.message,
  });

  final RouteRoutingFailureCode code;
  final String operationId;
  final String message;

  @override
  String toString() =>
      'RouteRoutingException(${code.name}, $operationId): $message';
}

class RouteRoutingEndpoint {
  const RouteRoutingEndpoint({required this.anchorId, required this.position});

  final String anchorId;
  final GeoPoint position;
}

class RouteRoutingRequest {
  const RouteRoutingRequest({
    required this.operationId,
    required this.expectedGeometryRevision,
    required this.requestFingerprint,
    required this.from,
    required this.to,
    required this.profile,
    required this.preferences,
    this.cancellationSignal,
  });

  final String operationId;
  final int expectedGeometryRevision;
  final String requestFingerprint;
  final RouteRoutingEndpoint from;
  final RouteRoutingEndpoint to;
  final RouteProfileRef profile;
  final RouteRoutingPreferences preferences;
  final RouteCancellationSignal? cancellationSignal;
}

class RouteRoutingResult {
  RouteRoutingResult({
    required this.operationId,
    required this.expectedGeometryRevision,
    required this.requestFingerprint,
    required this.fromAnchorId,
    required this.toAnchorId,
    required this.geometry,
    required this.provenance,
    Iterable<String> appliedPreferenceIds = const <String>[],
    Iterable<String> unsupportedPreferenceIds = const <String>[],
    this.providerDurationSeconds,
  }) : appliedPreferenceIds = List<String>.unmodifiable(appliedPreferenceIds),
       unsupportedPreferenceIds = List<String>.unmodifiable(
         unsupportedPreferenceIds,
       );

  final String operationId;
  final int expectedGeometryRevision;
  final String requestFingerprint;
  final String fromAnchorId;
  final String toAnchorId;
  final RouteGeometryDraft geometry;
  final RouteProvenanceDraft provenance;
  final List<String> appliedPreferenceIds;
  final List<String> unsupportedPreferenceIds;
  final int? providerDurationSeconds;
}

class RouteGenerationRequest {
  const RouteGenerationRequest({
    required this.operationId,
    required this.expectedGeometryRevision,
    required this.requestFingerprint,
    required this.origin,
    required this.profile,
    required this.preferences,
    required this.targetDistanceMeters,
    required this.shape,
    this.targetDurationSeconds,
    this.cancellationSignal,
  });

  final String operationId;
  final int expectedGeometryRevision;
  final String requestFingerprint;
  final GeoPoint origin;
  final RouteProfileRef profile;
  final RouteRoutingPreferences preferences;
  final double targetDistanceMeters;
  final int? targetDurationSeconds;
  final RouteShape shape;
  final RouteCancellationSignal? cancellationSignal;
}

class RouteGeneratedCandidate {
  RouteGeneratedCandidate({
    required this.candidateId,
    required this.operationId,
    required this.expectedGeometryRevision,
    required this.requestFingerprint,
    required Iterable<RouteAnchorDraft> anchors,
    required Iterable<RouteSegmentDraft> segments,
    required this.metrics,
  }) : anchors = List<RouteAnchorDraft>.unmodifiable(anchors),
       segments = List<RouteSegmentDraft>.unmodifiable(segments);

  final String candidateId;
  final String operationId;
  final int expectedGeometryRevision;
  final String requestFingerprint;
  final List<RouteAnchorDraft> anchors;
  final List<RouteSegmentDraft> segments;
  final RouteMetricsDraft metrics;
}

abstract interface class RouteRoutingRepository {
  Future<RouteRoutingResult> route(RouteRoutingRequest request);

  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  );
}
