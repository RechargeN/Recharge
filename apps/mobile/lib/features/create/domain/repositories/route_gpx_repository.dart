import '../../../../core/geo/geo_bounds.dart';
import '../../../../core/geo/geo_point.dart';
import '../entities/route_draft_data.dart';

enum RouteGpxCandidateKind { track, route }
enum RouteGpxGapResolution { direct, separate }
enum RouteGpxWaypointDecision { skip, attachNearest, keepOffTrack }

class RouteGpxImportConfig {
  const RouteGpxImportConfig({
    this.maximumFileBytes = 5 * 1024 * 1024,
    this.maximumSourcePoints = 200000,
    this.maximumCandidates = 1000,
    this.maximumSegments = 5000,
    this.maximumWaypoints = 10000,
    this.maximumXmlDepth = 64,
    this.maximumXmlEvents = 1000000,
    this.maximumTextCharacters = 10000,
  });

  final int maximumFileBytes;
  final int maximumSourcePoints;
  final int maximumCandidates;
  final int maximumSegments;
  final int maximumWaypoints;
  final int maximumXmlDepth;
  final int maximumXmlEvents;
  final int maximumTextCharacters;

  RouteGpxImportConfig validated() {
    if (maximumFileBytes <= 0 ||
        maximumSourcePoints < 2 ||
        maximumCandidates <= 0 ||
        maximumSegments <= 0 ||
        maximumWaypoints < 0 ||
        maximumXmlDepth < 4 ||
        maximumXmlEvents <= 0 ||
        maximumTextCharacters <= 0) {
      throw const RouteGpxException('gpx_config_invalid');
    }
    return this;
  }
}

class RouteSafeFileRef {
  const RouteSafeFileRef({
    required this.token,
    required this.displayName,
    required this.sizeBytes,
    required this.mediaType,
  });

  final String token;
  final String displayName;
  final int sizeBytes;
  final String mediaType;
}

class RouteGpxCandidateSummary {
  RouteGpxCandidateSummary({
    required this.kind,
    required this.sourceIndex,
    required this.segmentCount,
    required this.gapCount,
    required this.pointCount,
    required this.distanceMeters,
    required this.bounds,
    required this.hasTimestamps,
    required this.hasElevation,
    required Iterable<String> issueCodes,
    this.name,
    this.durationSeconds,
  }) : issueCodes = List<String>.unmodifiable(issueCodes);

  final RouteGpxCandidateKind kind;
  final int sourceIndex;
  final String? name;
  final int segmentCount;
  final int gapCount;
  final int pointCount;
  final double distanceMeters;
  final double? durationSeconds;
  final GeoBounds bounds;
  final bool hasTimestamps;
  final bool hasElevation;
  final List<String> issueCodes;

  String get selectionKey => '${kind.name}:$sourceIndex';
}

class RouteGpxWaypointSummary {
  RouteGpxWaypointSummary({
    required this.sourceIndex,
    required this.position,
    required this.hasTimestamp,
    required Iterable<String> extensionNames,
    this.name,
    this.type,
  }) : extensionNames = List<String>.unmodifiable(extensionNames);

  final int sourceIndex;
  final GeoPoint position;
  final String? name;
  final String? type;
  final bool hasTimestamp;
  final List<String> extensionNames;
}

class RouteGpxInspection {
  RouteGpxInspection({
    required this.file,
    required this.gpxVersion,
    required this.contentSha256,
    required Iterable<RouteGpxCandidateSummary> candidates,
    required Iterable<RouteGpxWaypointSummary> waypoints,
    required this.containsPrivateMetadata,
    required Iterable<String> unsupportedExtensionNames,
    required Iterable<String> issueCodes,
  }) : candidates = List<RouteGpxCandidateSummary>.unmodifiable(candidates),
       waypoints = List<RouteGpxWaypointSummary>.unmodifiable(waypoints),
       unsupportedExtensionNames = List<String>.unmodifiable(
         unsupportedExtensionNames,
       ),
       issueCodes = List<String>.unmodifiable(issueCodes);

  final RouteSafeFileRef file;
  final String gpxVersion;
  final String contentSha256;
  final List<RouteGpxCandidateSummary> candidates;
  final List<RouteGpxWaypointSummary> waypoints;
  final bool containsPrivateMetadata;
  final List<String> unsupportedExtensionNames;
  final List<String> issueCodes;

  int get waypointCount => waypoints.length;
  int get pointCount => candidates.fold<int>(
    0,
    (total, candidate) => total + candidate.pointCount,
  );
}

class RouteGpxImportSelection {
  RouteGpxImportSelection({
    required this.file,
    required Iterable<String> candidateKeys,
    required this.mergeTracks,
    required this.importWaypoints,
    required this.stripTimestamps,
    required this.stripPrivateMetadata,
    Map<String, RouteGpxGapResolution> gapResolutions =
        const <String, RouteGpxGapResolution>{},
    Map<int, RouteGpxWaypointDecision> waypointDecisions =
        const <int, RouteGpxWaypointDecision>{},
  }) : candidateKeys = List<String>.unmodifiable(candidateKeys),
       gapResolutions = Map<String, RouteGpxGapResolution>.unmodifiable(
         gapResolutions,
       ),
       waypointDecisions = Map<int, RouteGpxWaypointDecision>.unmodifiable(
         waypointDecisions,
       );

  final RouteSafeFileRef file;
  final List<String> candidateKeys;
  final bool mergeTracks;
  final bool importWaypoints;
  final bool stripTimestamps;
  final bool stripPrivateMetadata;
  final Map<String, RouteGpxGapResolution> gapResolutions;
  final Map<int, RouteGpxWaypointDecision> waypointDecisions;
}

class RouteGpxImportedWaypoint {
  const RouteGpxImportedWaypoint({
    required this.position,
    required this.typeId,
    required this.trackState,
    this.name,
    this.note,
  });

  final GeoPoint position;
  final String typeId;
  final RouteWaypointTrackState trackState;
  final String? name;
  final String? note;
}

class RouteGpxImportResult {
  RouteGpxImportResult({
    required Iterable<List<GeoPoint>> tracks,
    required Iterable<RouteGpxImportedWaypoint> waypoints,
    required Iterable<RouteSourceIssueDraft> sourceIssues,
    required this.provenance,
  }) : tracks = List<List<GeoPoint>>.unmodifiable(
         tracks.map(
           (List<GeoPoint> track) => List<GeoPoint>.unmodifiable(track),
         ),
       ),
       waypoints = List<RouteGpxImportedWaypoint>.unmodifiable(waypoints),
       sourceIssues = List<RouteSourceIssueDraft>.unmodifiable(sourceIssues);

  final List<List<GeoPoint>> tracks;
  final List<RouteGpxImportedWaypoint> waypoints;
  final List<RouteSourceIssueDraft> sourceIssues;
  final RouteProvenanceDraft provenance;
}

class RouteGpxExportRequest {
  const RouteGpxExportRequest({
    required this.routeId,
    required this.routeVersionId,
    required this.route,
    required this.includeElevation,
    required this.includeWaypoints,
  });

  final String routeId;
  final String routeVersionId;
  final RouteDraftData route;
  final bool includeElevation;
  final bool includeWaypoints;
}

class RouteGpxException implements Exception {
  const RouteGpxException(this.code);

  final String code;

  @override
  String toString() => 'RouteGpxException($code)';
}

abstract interface class RouteGpxRepository {
  Future<RouteGpxInspection> inspect(RouteSafeFileRef file);

  Future<RouteGpxImportResult> import(RouteGpxImportSelection selection);

  Future<RouteSafeFileRef> export(RouteGpxExportRequest request);

  Future<void> discard(RouteSafeFileRef file);
}
