import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/validate_route_draft_usecase.dart';

const routeFixtureRevision = 7;

RouteValidationPolicy routeValidationPolicy({
  bool requirePermanentIds = true,
  int maximumGeometryPoints = 10000,
}) => RouteValidationPolicy(
  profileRules: <RouteProfileValidationRule>[
    RouteProfileValidationRule(
      profile: const RouteProfileRef(id: 'walking', version: 1),
      minimumDistanceMeters: 1,
      maximumDistanceMeters: 500000,
      maximumDurationSeconds: 604800,
      allowedShapes: RouteShape.values,
      supportedPreferenceIds: const <String>['avoid_stairs', 'prefer_unpaved'],
    ),
  ],
  encodingPolicyId: RouteGeometryEncodingPolicyDraft.standard.id,
  encodingPolicyVersion: RouteGeometryEncodingPolicyDraft.standard.version,
  minimumAnchors: 2,
  maximumAnchors: 100,
  maximumSegments: 120,
  maximumWaypoints: 250,
  maximumGeometryPoints: maximumGeometryPoints,
  endpointToleranceMeters: 2,
  distanceToleranceMeters: 0.1,
  waypointTrackToleranceMeters: 25,
  maximumDirectShare: 0.2,
  manualDurationReasonDeviationRatio: 0.25,
  requirePermanentIds: requirePermanentIds,
);

RouteAnchorDraft routeAnchor(String id, double latitude, double longitude) =>
    RouteAnchorDraft(
      id: id,
      position: GeoPoint(latitude: latitude, longitude: longitude),
    );

RouteSegmentDraft routeSegment({
  required String id,
  required int order,
  required RouteAnchorDraft from,
  required RouteAnchorDraft to,
  int geometryRevision = routeFixtureRevision,
  RouteSegmentSource source = RouteSegmentSource.freehand,
  RouteSegmentOperationState operationState = RouteSegmentOperationState.ready,
  RouteRoutingFailureCode? fallbackReason,
  RouteGeometryDraft? geometry,
}) => RouteSegmentDraft(
  id: id,
  fromAnchorId: from.id,
  toAnchorId: to.id,
  order: order,
  source: source,
  derivation: RouteSegmentDerivation.original,
  geometry:
      geometry ??
      RouteGeometryDraft.fromPoints(<GeoPoint>[
        from.position,
        GeoPoint(
          latitude: (from.position.latitude + to.position.latitude) / 2,
          longitude: (from.position.longitude + to.position.longitude) / 2,
        ),
        to.position,
      ]),
  provenance: RouteProvenanceDraft(
    sourceId: 'author-device',
    sourceRevision: 1,
    createdAtUtc: DateTime.utc(2026, 7, 24, 8),
    algorithmVersion: 'manual-v1',
  ),
  geometryRevision: geometryRevision,
  operationState: operationState,
  fallbackReason: fallbackReason,
);

RouteDraftData routeFixture({
  int revision = 0,
  RouteShape shape = RouteShape.oneWay,
  List<RouteAnchorDraft>? anchors,
  List<RouteSegmentDraft>? segments,
  List<RouteWaypointDraft>? waypoints,
  RouteProfileRef profile = const RouteProfileRef(id: 'walking', version: 1),
  RouteRoutingPreferences? preferences,
  RouteMetricsDraft? metrics,
  RouteGeometryEncodingPolicyDraft encodingPolicy =
      RouteGeometryEncodingPolicyDraft.standard,
  List<RouteAsyncOperationDraft> operations =
      const <RouteAsyncOperationDraft>[],
  List<RouteSourceIssueDraft> sourceIssues = const <RouteSourceIssueDraft>[],
  String? turningAnchorId,
  int geometryRevision = routeFixtureRevision,
}) {
  final routeAnchors =
      anchors ??
      <RouteAnchorDraft>[
        routeAnchor('01ANCHOR000000000000000001', 56.9496, 24.1052),
        routeAnchor('01ANCHOR000000000000000002', 56.9520, 24.1150),
      ];
  final routeSegments =
      segments ??
      <RouteSegmentDraft>[
        routeSegment(
          id: '01SEGMENT00000000000000001',
          order: 0,
          from: routeAnchors[0],
          to: routeAnchors[1],
          geometryRevision: geometryRevision,
        ),
      ];
  final distance = routeSegments.fold<double>(
    0,
    (double total, RouteSegmentDraft segment) => total + segment.distanceMeters,
  );
  final routeMetrics =
      metrics ??
      RouteMetricsDraft(
        geometryRevision: geometryRevision,
        calculationModelId: 'walking-duration',
        calculationModelVersion: 1,
        distanceMeters: distance,
        autoDurationSeconds: 600,
        effectiveDurationSeconds: 600,
        directDistanceMeters: 0,
        fallbackDistanceMeters: 0,
        surfaceDistanceMeters: <String, double>{'mixed': distance},
      );
  final routeWaypoints =
      waypoints ??
      <RouteWaypointDraft>[
        RouteWaypointDraft(
          id: '01WAYPOINT0000000000000001',
          segmentId: routeSegments.first.id,
          position: routeSegments.first.geometry.points[1],
          typeId: 'viewpoint.v1',
          trackState: RouteWaypointTrackState.onTrack,
          distanceFromStartMeters: distance / 2,
          distanceFromTrackMeters: 0,
        ),
      ];

  return RouteDraftData(
    revision: revision,
    geometryRevision: geometryRevision,
    creationMethod: RouteCreationMethod.points,
    shape: shape,
    turningAnchorId: turningAnchorId,
    profile: profile,
    preferences:
        preferences ??
        RouteRoutingPreferences(
          values: const <String, RoutePreferenceValue>{
            'avoid_stairs': RouteBoolPreferenceValue(true),
          },
        ),
    anchors: routeAnchors,
    segments: routeSegments,
    waypoints: routeWaypoints,
    conditions: RouteConditionsDraft(
      difficultyId: 'easy.v1',
      surfaceIds: const <String>['mixed'],
      isMarked: true,
      bestTimeId: 'all_year.v1',
      verifiedAtUtc: DateTime.utc(2026, 7, 24),
    ),
    sourceIssues: sourceIssues,
    metrics: routeMetrics,
    encodingPolicy: encodingPolicy,
    operations: operations,
  );
}

RouteDraftData routeForPath({
  required RouteShape shape,
  required List<RouteAnchorDraft> path,
  String? turningAnchorId,
}) {
  final uniqueAnchors = <String, RouteAnchorDraft>{
    for (final anchor in path) anchor.id: anchor,
  }.values.toList(growable: false);
  final segments = <RouteSegmentDraft>[
    for (var index = 0; index < path.length - 1; index += 1)
      routeSegment(
        id: '01SEGMENT${index.toString().padLeft(16, '0')}',
        order: index,
        from: path[index],
        to: path[index + 1],
      ),
  ];
  return routeFixture(
    shape: shape,
    anchors: uniqueAnchors,
    segments: segments,
    waypoints: const <RouteWaypointDraft>[],
    turningAnchorId: turningAnchorId,
  );
}
