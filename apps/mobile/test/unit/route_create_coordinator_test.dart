import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/route_create_config.dart';
import 'package:recharge/features/create/application/route_create_coordinator.dart';
import 'package:recharge/features/create/application/route_draft_autosave_coordinator.dart';
import 'package:recharge/features/create/application/route_edit_command.dart';
import 'package:recharge/features/create/application/state/route_create_state.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_draft_save_result.dart';
import 'package:recharge/features/create/domain/repositories/route_draft_persistence_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_routing_repository.dart';
import 'package:recharge/features/create/domain/usecases/apply_route_edit_command_usecase.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  test('applies routing result inside the initiating history entry', () async {
    final routing = _ImmediateRoutingRepository();
    final persistence = _MemoryRoutePersistence();
    final coordinator = _coordinator(routing, persistence);
    final first = routeAnchor(
      '01ANCHOR000000000000000001',
      57.0014267,
      24.1446697,
    );
    coordinator.initialize(
      userId: 'creator-1',
      createDraft: _createDraft(
        _minimalRoute(anchors: <RouteAnchorDraft>[first]),
      ),
    );

    final outcome = await coordinator.execute(
      const AddRouteAnchor(
        position: GeoPoint(latitude: 57.0020, longitude: 24.1452),
      ),
    );

    expect(outcome.accepted, isTrue);
    expect(coordinator.state.status, RouteCreateStatus.ready);
    expect(coordinator.state.route.operations, isEmpty);
    expect(
      coordinator.state.route.segments.single.operationState,
      RouteSegmentOperationState.ready,
    );
    expect(coordinator.state.route.segments.single.provenance.sourceId, 'fake');
    expect(coordinator.state.undoStack, hasLength(1));
    expect(
      coordinator
          .state
          .undoStack
          .single
          .after
          .segments
          .single
          .geometry
          .geometryHash,
      coordinator.state.route.segments.single.geometry.geometryHash,
    );
    await coordinator.dispose();
  });

  test('late routing response cannot overwrite a newer command', () async {
    final routing = _ControlledRoutingRepository();
    final persistence = _MemoryRoutePersistence();
    final coordinator = _coordinator(routing, persistence);
    final draft = _routedFixture();
    coordinator.initialize(
      userId: 'creator-1',
      createDraft: _createDraft(draft),
    );

    final move = coordinator.execute(
      MoveRouteAnchor(
        anchorId: draft.anchors.last.id,
        position: const GeoPoint(latitude: 56.9530, longitude: 24.1160),
      ),
    );
    expect(routing.requests, hasLength(1));
    final segmentId = coordinator.state.route.segments.single.id;
    final direct = await coordinator.execute(
      SetRouteSegmentDirect(segmentId: segmentId),
    );
    final directHash =
        coordinator.state.route.segments.single.geometry.geometryHash;

    routing.complete(0);
    await move;

    expect(direct.accepted, isTrue);
    expect(
      coordinator.state.route.segments.single.source,
      RouteSegmentSource.intentionalDirect,
    );
    expect(
      coordinator.state.route.segments.single.geometry.geometryHash,
      directHash,
    );
    expect(coordinator.state.ignoredStaleResponses, 1);
    await coordinator.dispose();
  });

  test(
    'undo and redo restore exact geometry with increasing revisions',
    () async {
      final persistence = _MemoryRoutePersistence();
      final coordinator = _coordinator(
        _ImmediateRoutingRepository(),
        persistence,
      );
      final draft = _routedFixture();
      coordinator.initialize(
        userId: 'creator-1',
        createDraft: _createDraft(draft),
      );
      final beforeHash = draft.segments.single.geometry.geometryHash;

      await coordinator.execute(
        SetRouteSegmentDirect(segmentId: draft.segments.single.id),
      );
      final afterHash =
          coordinator.state.route.segments.single.geometry.geometryHash;
      final afterRevision = coordinator.state.route.geometryRevision;

      expect(coordinator.undo(), isTrue);
      expect(
        coordinator.state.route.segments.single.geometry.geometryHash,
        beforeHash,
      );
      expect(
        coordinator.state.route.geometryRevision,
        greaterThan(afterRevision),
      );
      expect(coordinator.redo(), isTrue);
      expect(
        coordinator.state.route.segments.single.geometry.geometryHash,
        afterHash,
      );
      expect(coordinator.state.canRedo, isFalse);
      await coordinator.dispose();
    },
  );

  test(
    'a rejected command does not enter history or clear the draft',
    () async {
      final coordinator = _coordinator(
        _ImmediateRoutingRepository(),
        _MemoryRoutePersistence(),
      );
      final draft = _routedFixture();
      coordinator.initialize(
        userId: 'creator-1',
        createDraft: _createDraft(draft),
      );
      final initializedDraft = coordinator.state.route;

      final outcome = await coordinator.execute(
        const RemoveRouteAnchor(anchorId: 'missing'),
      );

      expect(outcome.accepted, isFalse);
      expect(outcome.failureCode, RouteEditFailureCode.anchorNotFound);
      expect(coordinator.state.undoStack, isEmpty);
      expect(coordinator.state.route, same(initializedDraft));
      await coordinator.dispose();
    },
  );

  test(
    'routing failure is local to its segment and remains recoverable',
    () async {
      final coordinator = _coordinator(
        const _FailingRoutingRepository(),
        _MemoryRoutePersistence(),
      );
      final a = routeAnchor('01ANCHOR000000000000000001', 56.95, 24.10);
      final b = routeAnchor('01ANCHOR000000000000000002', 56.96, 24.11);
      final c = routeAnchor('01ANCHOR000000000000000003', 56.97, 24.12);
      final base = routeForPath(
        shape: RouteShape.oneWay,
        path: <RouteAnchorDraft>[a, b, c],
      );
      final draft = base.copyWith(
        segments: base.segments
            .map(
              (RouteSegmentDraft segment) =>
                  segment.copyWith(source: RouteSegmentSource.routed),
            )
            .toList(growable: false),
      );
      final untouchedHash = draft.orderedSegments.first.geometry.geometryHash;
      coordinator.initialize(
        userId: 'creator-1',
        createDraft: _createDraft(draft),
      );

      await coordinator.execute(
        MoveRouteAnchor(
          anchorId: c.id,
          position: const GeoPoint(latitude: 56.971, longitude: 24.121),
        ),
      );

      expect(coordinator.state.status, RouteCreateStatus.failed);
      expect(
        coordinator.state.route.orderedSegments.first.geometry.geometryHash,
        untouchedHash,
      );
      expect(
        coordinator.state.route.orderedSegments.last.operationState,
        RouteSegmentOperationState.failed,
      );
      expect(
        coordinator.state.route.orderedSegments.last.fallbackReason,
        RouteRoutingFailureCode.noPath,
      );
      await coordinator.dispose();
    },
  );

  test(
    'autosave refuses pending commands and saves the completed revision',
    () async {
      final routing = _ControlledRoutingRepository();
      final persistence = _MemoryRoutePersistence();
      final coordinator = _coordinator(routing, persistence);
      final draft = _routedFixture();
      coordinator.initialize(
        userId: 'creator-1',
        createDraft: _createDraft(draft),
      );

      final move = coordinator.execute(
        MoveRouteAnchor(
          anchorId: draft.anchors.last.id,
          position: const GeoPoint(latitude: 56.9530, longitude: 24.1160),
        ),
      );
      final pendingSave = await coordinator.flushAutosave();

      expect(pendingSave.status, RouteDraftSaveStatus.invalidDraft);
      expect(persistence.calls, 0);

      routing.complete(0);
      await move;
      final completedSave = await coordinator.flushAutosave();

      expect(completedSave.status, RouteDraftSaveStatus.saved);
      expect(persistence.calls, 1);
      expect(
        coordinator.state.persistedRevision,
        coordinator.state.route.revision,
      );
      await coordinator.dispose();
    },
  );

  test('an older autosave completion cannot mark a newer edit saved', () async {
    final persistence = _BlockingFirstRoutePersistence();
    final coordinator = _coordinator(
      _ImmediateRoutingRepository(),
      persistence,
    );
    final routed = _routedFixture();
    final draft = routed.copyWith(
      segments: <RouteSegmentDraft>[
        routed.segments.single.copyWith(
          source: RouteSegmentSource.intentionalDirect,
        ),
      ],
    );
    coordinator.initialize(
      userId: 'creator-1',
      createDraft: _createDraft(draft),
    );

    await coordinator.execute(
      MoveRouteAnchor(
        anchorId: draft.anchors.last.id,
        position: const GeoPoint(latitude: 56.953, longitude: 24.116),
      ),
    );
    final firstSavedRevision = coordinator.state.route.revision;
    final firstSave = coordinator.flushAutosave();
    await Future<void>.delayed(Duration.zero);

    await coordinator.execute(
      MoveRouteAnchor(
        anchorId: draft.anchors.last.id,
        position: const GeoPoint(latitude: 56.954, longitude: 24.117),
      ),
    );
    expect(coordinator.state.route.revision, greaterThan(firstSavedRevision));

    persistence.completeFirst();
    expect((await firstSave).isSaved, isTrue);
    expect(coordinator.state.persistedRevision, firstSavedRevision);
    expect(coordinator.state.status, RouteCreateStatus.ready);
    expect(
      coordinator.state.route.revision,
      greaterThan(coordinator.state.persistedRevision),
    );
    await coordinator.dispose();
  });

  test(
    'history is bounded and restore returns to the persisted geometry',
    () async {
      final coordinator = _coordinator(
        _ImmediateRoutingRepository(),
        _MemoryRoutePersistence(),
        maximumHistoryEntries: 2,
      );
      final routed = _routedFixture();
      final draft = routed.copyWith(
        segments: <RouteSegmentDraft>[
          routed.segments.single.copyWith(
            source: RouteSegmentSource.intentionalDirect,
          ),
        ],
      );
      final persistedHash = draft.segments.single.geometry.geometryHash;
      coordinator.initialize(
        userId: 'creator-1',
        createDraft: _createDraft(draft),
      );

      for (var index = 0; index < 3; index += 1) {
        await coordinator.execute(
          MoveRouteAnchor(
            anchorId: draft.anchors.last.id,
            position: GeoPoint(
              latitude: 56.953 + index / 1000,
              longitude: 24.116 + index / 1000,
            ),
          ),
        );
      }

      expect(coordinator.state.undoStack, hasLength(2));
      final restored = coordinator.restorePersistedRevision();
      expect(restored.accepted, isTrue);
      expect(
        coordinator.state.route.segments.single.geometry.geometryHash,
        persistedHash,
      );
      await coordinator.dispose();
    },
  );
}

RouteCreateCoordinator _coordinator(
  RouteRoutingRepository routing,
  RouteDraftPersistenceRepository persistence, {
  int maximumHistoryEntries = 10,
}) => RouteCreateCoordinator(
  idGenerator: _SequenceIdGenerator(),
  routingRepository: routing,
  autosaveCoordinator: RouteDraftAutosaveCoordinator(persistence),
  config: RouteCreateConfig(
    version: 1,
    validationPolicy: routeValidationPolicy(requirePermanentIds: false),
    autosaveDebounce: const Duration(hours: 1),
    minimumHistoryEntries: 1,
    maximumHistoryEntries: maximumHistoryEntries,
    maximumHistoryGeometryPoints: 10000,
  ),
  clock: () => DateTime.utc(2026, 7, 24, 12),
);

CreateDraftEntity _createDraft(RouteDraftData route) =>
    CreateDraftEntity.defaults(
      organizerId: 'creator-1',
      organizerEmail: 'creator@example.test',
      organizerName: 'Creator',
    ).copyWith(
      objectType: CreateObjectType.route,
      routeData: route,
      clearEventData: true,
    );

RouteDraftData _routedFixture() {
  final base = routeFixture();
  return base.copyWith(
    segments: <RouteSegmentDraft>[
      base.segments.single.copyWith(source: RouteSegmentSource.routed),
    ],
  );
}

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

RouteRoutingResult _result(RouteRoutingRequest request) {
  final midpoint = GeoPoint(
    latitude:
        (request.from.position.latitude + request.to.position.latitude) / 2,
    longitude:
        (request.from.position.longitude + request.to.position.longitude) / 2,
  );
  return RouteRoutingResult(
    operationId: request.operationId,
    expectedGeometryRevision: request.expectedGeometryRevision,
    requestFingerprint: request.requestFingerprint,
    fromAnchorId: request.from.anchorId,
    toAnchorId: request.to.anchorId,
    geometry: RouteGeometryDraft.fromPoints(<GeoPoint>[
      request.from.position,
      midpoint,
      request.to.position,
    ]),
    provenance: RouteProvenanceDraft(
      sourceId: 'fake',
      sourceRevision: 1,
      createdAtUtc: DateTime.utc(2026, 7, 24, 12),
      algorithmVersion: 'fake-v1',
      provider: const RouteProviderReference(
        code: 'fake',
        attribution: 'Test',
        licenseId: 'test',
        dataVersion: 'v1',
        allowsPublication: false,
      ),
    ),
    providerDurationSeconds: 300,
  );
}

class _ImmediateRoutingRepository implements RouteRoutingRepository {
  @override
  Future<RouteRoutingResult> route(RouteRoutingRequest request) async =>
      _result(request);

  @override
  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  ) async => const <RouteGeneratedCandidate>[];
}

class _ControlledRoutingRepository implements RouteRoutingRepository {
  final List<RouteRoutingRequest> requests = <RouteRoutingRequest>[];
  final List<Completer<RouteRoutingResult>> _completers =
      <Completer<RouteRoutingResult>>[];

  @override
  Future<RouteRoutingResult> route(RouteRoutingRequest request) {
    requests.add(request);
    final completer = Completer<RouteRoutingResult>();
    _completers.add(completer);
    return completer.future;
  }

  void complete(int index) {
    _completers[index].complete(_result(requests[index]));
  }

  @override
  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  ) async => const <RouteGeneratedCandidate>[];
}

class _FailingRoutingRepository implements RouteRoutingRepository {
  const _FailingRoutingRepository();

  @override
  Future<RouteRoutingResult> route(RouteRoutingRequest request) async {
    throw RouteRoutingException(
      code: RouteRoutingFailureCode.noPath,
      operationId: request.operationId,
      message: 'No path.',
    );
  }

  @override
  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  ) async => const <RouteGeneratedCandidate>[];
}

class _MemoryRoutePersistence implements RouteDraftPersistenceRepository {
  int calls = 0;

  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async {
    calls += 1;
    return RouteDraftSaveResult(
      status: RouteDraftSaveStatus.saved,
      requestedRevision: draft.routeData!.revision,
      persistedRevision: draft.routeData!.revision,
    );
  }
}

class _BlockingFirstRoutePersistence
    implements RouteDraftPersistenceRepository {
  final Completer<void> _firstRelease = Completer<void>();
  int calls = 0;

  void completeFirst() => _firstRelease.complete();

  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async {
    calls += 1;
    if (calls == 1) {
      await _firstRelease.future;
    }
    final revision = draft.routeData!.revision;
    return RouteDraftSaveResult(
      status: RouteDraftSaveStatus.saved,
      requestedRevision: revision,
      persistedRevision: revision,
    );
  }
}

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'id_${_next++}';
}
