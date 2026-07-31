import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_validation_issue.dart';
import 'package:recharge/features/create/domain/usecases/validate_route_draft_usecase.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  const validator = ValidateRouteDraftUseCase();

  RouteReadiness readiness(
    RouteDraftData route, {
    RouteValidationPolicy? policy,
  }) => validator.evaluate(route, policy: policy ?? routeValidationPolicy());

  group('Route readiness', () {
    test('accepts a complete canonical route', () {
      final result = readiness(routeFixture());

      expect(result.canPublish, isTrue);
      expect(result.issues, isEmpty);
    });

    test('rejects temporary and duplicate nested ids before publication', () {
      final first = routeAnchor('loc_anchor', 56.94, 24.10);
      final second = routeAnchor('01ANCHOR000000000000000002', 56.95, 24.11);
      final segment = routeSegment(
        id: 'loc_anchor',
        order: 0,
        from: first,
        to: second,
      );

      final result = readiness(
        routeFixture(
          anchors: <RouteAnchorDraft>[first, second],
          segments: <RouteSegmentDraft>[segment],
          waypoints: const <RouteWaypointDraft>[],
        ),
      );
      final codes = result.blockingIssues
          .map((RouteValidationIssue issue) => issue.code)
          .toSet();

      expect(codes, contains('temporary_id_not_publishable'));
      expect(codes, contains('entity_id_duplicate'));
    });

    test('rejects corrupt geometry, stale revisions, and endpoint drift', () {
      final first = routeAnchor('01ANCHOR000000000000000001', 56.94, 24.10);
      final second = routeAnchor('01ANCHOR000000000000000002', 56.95, 24.11);
      final canonical = RouteGeometryDraft.fromPoints(const <GeoPoint>[
        GeoPoint(latitude: 56.9405, longitude: 24.1005),
        GeoPoint(latitude: 56.95, longitude: 24.11),
      ]);
      final corrupt = RouteGeometryDraft(
        points: canonical.points,
        encodingPolicy: canonical.encodingPolicy,
        encodedPolyline: canonical.encodedPolyline,
        geometryHash: 'corrupt',
        bounds: canonical.bounds,
        lengthMeters: canonical.lengthMeters,
      );
      final segment = routeSegment(
        id: '01SEGMENT00000000000000001',
        order: 0,
        from: first,
        to: second,
        geometryRevision: routeFixtureRevision - 1,
        geometry: corrupt,
      );

      final codes = readiness(
        routeFixture(
          anchors: <RouteAnchorDraft>[first, second],
          segments: <RouteSegmentDraft>[segment],
          waypoints: const <RouteWaypointDraft>[],
        ),
      ).blockingIssues.map((RouteValidationIssue issue) => issue.code);

      expect(codes, contains('segment_revision_stale'));
      expect(codes, contains('segment_geometry_hash_mismatch'));
      expect(codes, contains('segment_start_mismatch'));
    });

    test('blocks unresolved waypoints and invalid relations', () {
      final base = routeFixture();
      final waypoint = RouteWaypointDraft(
        id: '01WAYPOINT0000000000000002',
        segmentId: 'missing-segment',
        position: base.anchors.first.position,
        typeId: 'water.v1',
        trackState: RouteWaypointTrackState.unresolved,
      );

      final codes = readiness(
        routeFixture(waypoints: <RouteWaypointDraft>[waypoint]),
      ).blockingIssues.map((RouteValidationIssue issue) => issue.code);

      expect(codes, contains('waypoint_segment_missing'));
      expect(codes, contains('waypoint_unresolved'));
    });

    test('blocks every operation that still affects the snapshot', () {
      final result = readiness(
        routeFixture(
          operations: const <RouteAsyncOperationDraft>[
            RouteAsyncOperationDraft(
              operationId: '01OPERATION0000000000000001',
              kind: RouteAsyncOperationKind.routing,
              status: RouteAsyncOperationStatus.pending,
              expectedGeometryRevision: routeFixtureRevision,
              requestFingerprint: 'sha256:request',
            ),
          ],
        ),
      );

      expect(result.canPublish, isFalse);
      expect(
        result.blockingIssues.map((RouteValidationIssue issue) => issue.code),
        contains('operation_pending'),
      );
    });

    test('blocks provider geometry whose license forbids publication', () {
      final base = routeFixture();
      final oldSegment = base.segments.single;
      final segment = RouteSegmentDraft(
        id: oldSegment.id,
        fromAnchorId: oldSegment.fromAnchorId,
        toAnchorId: oldSegment.toAnchorId,
        order: oldSegment.order,
        source: RouteSegmentSource.routed,
        derivation: oldSegment.derivation,
        geometry: oldSegment.geometry,
        provenance: RouteProvenanceDraft(
          sourceId: 'provider-source',
          sourceRevision: 1,
          createdAtUtc: DateTime.utc(2026, 7, 24),
          provider: const RouteProviderReference(
            code: 'restricted',
            attribution: 'Restricted data',
            licenseId: 'internal-only-v1',
            dataVersion: '2026-07',
            allowsPublication: false,
          ),
        ),
        geometryRevision: oldSegment.geometryRevision,
      );

      expect(
        readiness(
          routeFixture(
            segments: <RouteSegmentDraft>[segment],
            waypoints: const <RouteWaypointDraft>[],
          ),
        ).blockingIssues.map((RouteValidationIssue issue) => issue.code),
        contains('provider_license_disallows_publish'),
      );
    });

    test('emits stable deduplicated warnings for accepted-risk sources', () {
      final base = routeFixture();
      final original = base.segments.single;
      final fallback = routeSegment(
        id: original.id,
        order: 0,
        from: base.anchors[0],
        to: base.anchors[1],
        source: RouteSegmentSource.fallbackDirect,
        fallbackReason: RouteRoutingFailureCode.noPath,
      );
      final fallbackMetrics = RouteMetricsDraft(
        geometryRevision: routeFixtureRevision,
        calculationModelId: 'walking-duration',
        calculationModelVersion: 1,
        distanceMeters: fallback.distanceMeters,
        autoDurationSeconds: 600,
        effectiveDurationSeconds: 600,
        directDistanceMeters: 0,
        fallbackDistanceMeters: fallback.distanceMeters,
        surfaceDistanceMeters: <String, double>{
          'mixed': fallback.distanceMeters,
        },
      );
      final result = readiness(
        routeFixture(
          segments: <RouteSegmentDraft>[fallback],
          waypoints: const <RouteWaypointDraft>[],
          metrics: fallbackMetrics,
          sourceIssues: <RouteSourceIssueDraft>[
            RouteSourceIssueDraft(
              id: '01ISSUE000000000000000001',
              code: 'surface_incomplete',
              severity: RouteSourceIssueSeverity.warning,
              segmentId: fallback.id,
            ),
            RouteSourceIssueDraft(
              id: '01ISSUE000000000000000002',
              code: 'surface_incomplete',
              severity: RouteSourceIssueSeverity.warning,
              segmentId: fallback.id,
            ),
          ],
        ),
      );

      expect(result.canPublish, isTrue);
      expect(
        result.warnings
            .where(
              (RouteValidationIssue issue) =>
                  issue.code == 'surface_incomplete',
            )
            .length,
        1,
      );
      expect(
        result.warnings.map((RouteValidationIssue issue) => issue.stableId),
        everyElement(isNotEmpty),
      );
    });

    test('rejects mismatched metrics and unsupported profile options', () {
      final base = routeFixture();
      final invalidMetrics = RouteMetricsDraft(
        geometryRevision: routeFixtureRevision,
        calculationModelId: 'walking-duration',
        calculationModelVersion: 1,
        distanceMeters: base.metrics.distanceMeters + 50,
        autoDurationSeconds: 600,
        effectiveDurationSeconds: 600,
        directDistanceMeters: 0,
        fallbackDistanceMeters: 0,
        surfaceDistanceMeters: <String, double>{
          'mixed': base.metrics.distanceMeters + 50,
        },
      );
      final result = readiness(
        routeFixture(
          metrics: invalidMetrics,
          preferences: RouteRoutingPreferences(
            values: const <String, RoutePreferenceValue>{
              'unknown_option': RouteBoolPreferenceValue(true),
            },
          ),
        ),
      );
      final codes = result.blockingIssues
          .map((RouteValidationIssue issue) => issue.code)
          .toSet();

      expect(codes, contains('metrics_distance_mismatch'));
      expect(codes, contains('preference_unsupported'));
    });

    test('requires provider provenance for routed geometry', () {
      final base = routeFixture();
      final routed = routeSegment(
        id: base.segments.single.id,
        order: 0,
        from: base.anchors[0],
        to: base.anchors[1],
        source: RouteSegmentSource.routed,
      );

      expect(
        readiness(
          routeFixture(
            segments: <RouteSegmentDraft>[routed],
            waypoints: const <RouteWaypointDraft>[],
          ),
        ).blockingIssues.map((RouteValidationIssue issue) => issue.code),
        contains('provider_reference_required'),
      );
    });

    test('keeps direct metrics and effective duration derived from data', () {
      final base = routeFixture();
      final invalidMetrics = RouteMetricsDraft(
        geometryRevision: routeFixtureRevision,
        calculationModelId: 'walking-duration',
        calculationModelVersion: 1,
        distanceMeters: base.metrics.distanceMeters,
        autoDurationSeconds: 600,
        effectiveDurationSeconds: 700,
        directDistanceMeters: 10,
        fallbackDistanceMeters: 10,
        surfaceDistanceMeters: <String, double>{
          'mixed': base.metrics.distanceMeters,
        },
      );

      final codes = readiness(
        routeFixture(metrics: invalidMetrics),
      ).blockingIssues.map((RouteValidationIssue issue) => issue.code).toSet();

      expect(codes, contains('metrics_direct_distance_mismatch'));
      expect(codes, contains('metrics_fallback_distance_mismatch'));
      expect(codes, contains('effective_duration_mismatch'));
    });
  });

  test('rejects an invalid validation policy before evaluating data', () {
    final invalidPolicy = RouteValidationPolicy(
      profileRules: <RouteProfileValidationRule>[],
      encodingPolicyId: '',
      encodingPolicyVersion: 0,
      minimumAnchors: 1,
      maximumAnchors: 0,
      maximumSegments: 0,
      maximumWaypoints: -1,
      maximumGeometryPoints: 1,
      endpointToleranceMeters: -1,
      distanceToleranceMeters: -1,
      waypointTrackToleranceMeters: -1,
      maximumDirectShare: 2,
      manualDurationReasonDeviationRatio: -1,
      requirePermanentIds: true,
    );

    expect(
      () => validator.evaluate(routeFixture(), policy: invalidPolicy),
      throwsArgumentError,
    );
  });
}
