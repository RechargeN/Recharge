import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/route_edit_command.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_validation_issue.dart';
import 'package:recharge/features/create/domain/usecases/apply_route_edit_command_usecase.dart';
import 'package:recharge/features/create/domain/usecases/validate_route_draft_usecase.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  late ApplyRouteEditCommandUseCase apply;
  late _SequenceIdGenerator ids;

  setUp(() {
    ids = _SequenceIdGenerator();
    apply = ApplyRouteEditCommandUseCase(idGenerator: ids);
  });

  test('adds a pending graph segment as one atomic command', () {
    final first = routeAnchor(
      '01ANCHOR000000000000000001',
      57.0014267,
      24.1446697,
    );
    final draft = _minimalRoute(anchors: <RouteAnchorDraft>[first]);

    final result = _run(
      apply,
      draft,
      const AddRouteAnchor(
        position: GeoPoint(latitude: 57.0020, longitude: 24.1452),
      ),
    );

    expect(result.accepted, isTrue);
    expect(result.draft.anchors, hasLength(2));
    expect(result.draft.segments, hasLength(1));
    expect(
      result.draft.segments.single.operationState,
      RouteSegmentOperationState.routing,
    );
    expect(result.rerouteSegmentIds, <String>[result.draft.segments.single.id]);
    expect(result.draft.revision, draft.revision + 1);
    expect(result.draft.geometryRevision, draft.geometryRevision + 1);
  });

  test('moving a routed anchor invalidates only adjacent routing', () {
    final base = routeFixture();
    final routed = base.segments.single.copyWith(
      source: RouteSegmentSource.routed,
    );
    final draft = base.copyWith(segments: <RouteSegmentDraft>[routed]);

    final result = _run(
      apply,
      draft,
      MoveRouteAnchor(
        anchorId: draft.anchors.last.id,
        position: const GeoPoint(latitude: 56.9530, longitude: 24.1160),
      ),
    );

    expect(result.accepted, isTrue);
    expect(result.rerouteSegmentIds, <String>[routed.id]);
    expect(
      result.draft.segments.single.operationState,
      RouteSegmentOperationState.routing,
    );
    expect(
      result.draft.segments.single.geometry.points.last,
      const GeoPoint(latitude: 56.9530, longitude: 24.1160),
    );
  });

  test('does not reshape recorded geometry without a preview', () {
    final draft = routeFixture();

    final result = _run(
      apply,
      draft,
      MoveRouteAnchor(
        anchorId: draft.anchors.last.id,
        position: const GeoPoint(latitude: 56.9530, longitude: 24.1160),
      ),
    );

    expect(result.accepted, isFalse);
    expect(result.failureCode, RouteEditFailureCode.sourceRequiresPreview);
    expect(result.draft, same(draft));
  });

  test('split and merge restore the exact canonical geometry hash', () {
    final draft = routeFixture();
    final originalHash = draft.segments.single.geometry.geometryHash;
    final splitPoint = draft.segments.single.geometry.points[1];

    final split = _run(
      apply,
      draft,
      SplitRouteSegment(
        segmentId: draft.segments.single.id,
        position: splitPoint,
      ),
    );
    final merged = _run(
      apply,
      split.draft,
      MergeRouteSegments(
        firstSegmentId: split.draft.orderedSegments.first.id,
        secondSegmentId: split.draft.orderedSegments.last.id,
      ),
    );

    expect(split.accepted, isTrue);
    expect(split.draft.segments, hasLength(2));
    expect(merged.accepted, isTrue);
    expect(merged.draft.segments, hasLength(1));
    expect(merged.draft.segments.single.geometry.geometryHash, originalHash);
  });

  test('builds out-and-back with explicit mirrored derivation', () {
    final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
    final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
    final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
    final draft = routeForPath(
      shape: RouteShape.oneWay,
      path: <RouteAnchorDraft>[a, b, c],
    );

    final result = _run(
      apply,
      draft,
      const ChangeRouteShape(RouteShape.outAndBack),
    );
    final topologyIssues = const ValidateRouteDraftUseCase()(
      result.draft,
      policy: routeValidationPolicy(),
    ).where((issue) => issue.code.startsWith('topology_'));

    expect(result.accepted, isTrue);
    expect(result.draft.turningAnchorId, c.id);
    expect(result.draft.segments, hasLength(4));
    expect(
      result.draft.orderedSegments
          .skip(2)
          .every(
            (RouteSegmentDraft segment) =>
                segment.derivation == RouteSegmentDerivation.mirrored,
          ),
      isTrue,
    );
    expect(topologyIssues, isEmpty);
  });

  test('adding an anchor preserves loop topology', () {
    final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
    final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
    final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
    final draft = _asRouted(
      routeForPath(
        shape: RouteShape.loop,
        path: <RouteAnchorDraft>[a, b, c, a],
      ),
    );

    final result = _run(
      apply,
      draft,
      const AddRouteAnchor(
        position: GeoPoint(latitude: 56.965, longitude: 24.125),
      ),
    );

    expect(result.accepted, isTrue);
    expect(result.draft.segments, hasLength(draft.segments.length + 1));
    expect(result.rerouteSegmentIds, hasLength(2));
    expect(_topologyIssues(result.draft), isEmpty);
  });

  test('adding an anchor extends both out-and-back legs atomically', () {
    final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
    final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
    final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
    final draft = _asRouted(
      routeForPath(
        shape: RouteShape.outAndBack,
        path: <RouteAnchorDraft>[a, b, c, b, a],
        turningAnchorId: c.id,
      ),
    );

    final result = _run(
      apply,
      draft,
      const AddRouteAnchor(
        position: GeoPoint(latitude: 56.98, longitude: 24.13),
      ),
    );

    expect(result.accepted, isTrue);
    expect(result.draft.segments, hasLength(draft.segments.length + 2));
    expect(result.draft.turningAnchorId, result.draft.anchors.last.id);
    expect(result.rerouteSegmentIds, hasLength(2));
    expect(_topologyIssues(result.draft), isEmpty);
  });

  test('removing a loop anchor reconnects the cycle atomically', () {
    final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
    final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
    final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
    final draft = _asRouted(
      routeForPath(
        shape: RouteShape.loop,
        path: <RouteAnchorDraft>[a, b, c, a],
      ),
    );

    final result = _run(apply, draft, RemoveRouteAnchor(anchorId: b.id));

    expect(result.accepted, isTrue);
    expect(result.draft.anchors, hasLength(2));
    expect(result.draft.segments, hasLength(2));
    expect(result.rerouteSegmentIds, hasLength(1));
    expect(_topologyIssues(result.draft), isEmpty);
  });

  test('removing an internal out-and-back anchor preserves both legs', () {
    final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
    final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
    final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
    final draft = _asRouted(
      routeForPath(
        shape: RouteShape.outAndBack,
        path: <RouteAnchorDraft>[a, b, c, b, a],
        turningAnchorId: c.id,
      ),
    );

    final result = _run(apply, draft, RemoveRouteAnchor(anchorId: b.id));

    expect(result.accepted, isTrue);
    expect(
      result.draft.anchors.map((anchor) => anchor.id),
      isNot(contains(b.id)),
    );
    expect(result.draft.segments, hasLength(2));
    expect(result.rerouteSegmentIds, hasLength(2));
    expect(_topologyIssues(result.draft), isEmpty);
  });

  test('removing the turning anchor promotes the previous anchor', () {
    final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
    final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
    final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
    final draft = _asRouted(
      routeForPath(
        shape: RouteShape.outAndBack,
        path: <RouteAnchorDraft>[a, b, c, b, a],
        turningAnchorId: c.id,
      ),
    );

    final result = _run(apply, draft, RemoveRouteAnchor(anchorId: c.id));

    expect(result.accepted, isTrue);
    expect(result.draft.turningAnchorId, b.id);
    expect(result.draft.segments, hasLength(2));
    expect(_topologyIssues(result.draft), isEmpty);
  });

  test('split keeps anchor order and later add extends the route end', () {
    final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
    final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
    final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
    final draft = routeForPath(
      shape: RouteShape.oneWay,
      path: <RouteAnchorDraft>[a, b, c],
    );
    final first = draft.orderedSegments.first;
    final split = _run(
      apply,
      draft,
      SplitRouteSegment(
        segmentId: first.id,
        position: first.geometry.points[1],
      ),
    );
    final added = _run(
      apply,
      split.draft,
      const AddRouteAnchor(
        position: GeoPoint(latitude: 56.98, longitude: 24.13),
      ),
    );

    expect(split.draft.anchors[1].id, startsWith('loc_'));
    expect(added.draft.orderedSegments.last.fromAnchorId, c.id);
    expect(_topologyIssues(added.draft), isEmpty);
  });

  test('changing one segment profile does not mutate its neighbor', () {
    final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
    final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
    final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
    final base = routeForPath(
      shape: RouteShape.oneWay,
      path: <RouteAnchorDraft>[a, b, c],
    );
    final routed = base.segments
        .map(
          (RouteSegmentDraft segment) =>
              segment.copyWith(source: RouteSegmentSource.routed),
        )
        .toList(growable: false);
    final draft = base.copyWith(segments: routed);
    const override = RouteProfileRef(id: 'walking-accessible', version: 1);

    final result = _run(
      apply,
      draft,
      ChangeRouteSegmentProfile(segmentId: routed.first.id, profile: override),
    );

    expect(result.accepted, isTrue);
    expect(result.draft.orderedSegments.first.profileOverride?.id, override.id);
    expect(result.draft.orderedSegments.last.profileOverride, isNull);
    expect(result.rerouteSegmentIds, <String>[routed.first.id]);
  });

  test(
    'failed command returns the original draft without a revision change',
    () {
      final draft = routeFixture();

      final result = _run(
        apply,
        draft,
        const RemoveRouteAnchor(anchorId: 'missing'),
      );

      expect(result.accepted, isFalse);
      expect(result.failureCode, RouteEditFailureCode.anchorNotFound);
      expect(result.draft, same(draft));
      expect(result.draft.revision, draft.revision);
    },
  );

  test('method replacement requires explicit confirmation', () {
    final draft = routeFixture();

    final blocked = _run(
      apply,
      draft,
      const SelectRouteCreationMethod(method: RouteCreationMethod.freehand),
    );
    final confirmed = _run(
      apply,
      draft,
      const SelectRouteCreationMethod(
        method: RouteCreationMethod.freehand,
        confirmGeometryReplacement: true,
      ),
    );

    expect(
      blocked.failureCode,
      RouteEditFailureCode.geometryReplacementConfirmationRequired,
    );
    expect(confirmed.accepted, isTrue);
    expect(confirmed.draft.anchors, isEmpty);
    expect(confirmed.draft.segments, isEmpty);
  });

  test(
    'freehand replacement is confirmed and keeps exact sampled geometry',
    () {
      final draft = routeFixture();
      final points = <GeoPoint>[
        const GeoPoint(latitude: 56.95, longitude: 24.10),
        const GeoPoint(latitude: 56.955, longitude: 24.105),
        const GeoPoint(latitude: 56.96, longitude: 24.11),
      ];

      final blocked = _run(
        apply,
        draft,
        ApplyRouteFreehandGeometry(points: points),
      );
      final accepted = _run(
        apply,
        draft,
        ApplyRouteFreehandGeometry(
          points: points,
          confirmGeometryReplacement: true,
        ),
      );

      expect(
        blocked.failureCode,
        RouteEditFailureCode.geometryReplacementConfirmationRequired,
      );
      expect(accepted.accepted, isTrue);
      expect(accepted.draft.creationMethod, RouteCreationMethod.freehand);
      expect(accepted.draft.shape, RouteShape.oneWay);
      expect(
        accepted.draft.segments.single.source,
        RouteSegmentSource.freehand,
      );
      expect(accepted.draft.segments.single.geometry.points, points);
    },
  );

  test('waypoint can be added, moved and removed by stable anchor ids', () {
    final base = routeFixture(waypoints: const <RouteWaypointDraft>[]);
    final added = _run(
      apply,
      base,
      AddRouteWaypoint(anchorId: base.anchors.first.id, typeId: 'viewpoint.v1'),
    );
    final waypoint = added.draft.waypoints.single;
    final moved = _run(
      apply,
      added.draft,
      MoveRouteWaypoint(
        waypointId: waypoint.id,
        anchorId: base.anchors.last.id,
      ),
    );
    final removed = _run(apply, moved.draft, RemoveRouteWaypoint(waypoint.id));

    expect(added.accepted, isTrue);
    expect(waypoint.distanceFromStartMeters, 0);
    expect(moved.draft.waypoints.single.anchorId, base.anchors.last.id);
    expect(
      moved.draft.waypoints.single.distanceFromStartMeters,
      closeTo(base.metrics.distanceMeters, 0.1),
    );
    expect(removed.draft.waypoints, isEmpty);
  });
}

RouteEditApplyResult _run(
  ApplyRouteEditCommandUseCase apply,
  RouteDraftData draft,
  RouteEditCommand command,
) => apply(
  draft,
  command,
  nowUtc: DateTime.utc(2026, 7, 24, 12),
  maximumAnchors: 100,
  maximumSegments: 120,
  maximumWaypoints: 250,
  maximumGeometryPoints: 10000,
);

Iterable<RouteValidationIssue> _topologyIssues(RouteDraftData draft) =>
    const ValidateRouteDraftUseCase()(
      draft,
      policy: routeValidationPolicy(requirePermanentIds: false),
    ).where((RouteValidationIssue issue) => issue.code.startsWith('topology_'));

RouteDraftData _asRouted(RouteDraftData draft) => draft.copyWith(
  segments: draft.orderedSegments
      .map(
        (RouteSegmentDraft segment) => segment.copyWith(
          source: RouteSegmentSource.routed,
          derivation: segment.order >= draft.orderedSegments.length / 2
              ? RouteSegmentDerivation.mirrored
              : RouteSegmentDerivation.original,
        ),
      )
      .toList(growable: false),
);

RouteDraftData _minimalRoute({
  List<RouteAnchorDraft> anchors = const <RouteAnchorDraft>[],
}) => RouteDraftData(
  geometryRevision: 0,
  creationMethod: RouteCreationMethod.points,
  shape: RouteShape.oneWay,
  profile: const RouteProfileRef(id: 'walking', version: 1),
  preferences: RouteRoutingPreferences(),
  anchors: anchors,
  segments: const <RouteSegmentDraft>[],
  waypoints: const <RouteWaypointDraft>[],
  conditions: RouteConditionsDraft(),
  sourceIssues: const <RouteSourceIssueDraft>[],
  metrics: RouteMetricsDraft(
    geometryRevision: 0,
    calculationModelId: 'walking-duration',
    calculationModelVersion: 1,
    distanceMeters: 0,
    autoDurationSeconds: 0,
    effectiveDurationSeconds: 0,
    directDistanceMeters: 0,
    fallbackDistanceMeters: 0,
  ),
  encodingPolicy: RouteGeometryEncodingPolicyDraft.standard,
);

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'id_${_next++}';
}
