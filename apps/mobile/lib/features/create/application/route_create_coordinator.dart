import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/geo/geo_point.dart';
import '../../../core/id/id_generator.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/route_draft_data.dart';
import '../domain/entities/route_draft_save_result.dart';
import '../domain/entities/route_validation_issue.dart';
import '../domain/repositories/route_quality_calculator.dart';
import '../domain/repositories/route_gpx_repository.dart';
import '../domain/repositories/route_routing_repository.dart';
import '../domain/usecases/apply_route_edit_command_usecase.dart';
import '../domain/usecases/calculate_route_quality_usecase.dart';
import '../domain/usecases/validate_route_draft_usecase.dart';
import 'route_create_config.dart';
import 'route_draft_autosave_coordinator.dart';
import 'route_edit_command.dart';
import 'state/route_create_state.dart';

class RouteCommandOutcome {
  const RouteCommandOutcome({required this.accepted, this.failureCode});

  final bool accepted;
  final RouteEditFailureCode? failureCode;
}

class RouteCreateCoordinator {
  RouteCreateCoordinator({
    required IdGenerator idGenerator,
    required RouteRoutingRepository routingRepository,
    required RouteDraftAutosaveCoordinator autosaveCoordinator,
    required RouteCreateConfig config,
    ValidateRouteDraftUseCase validateRoute = const ValidateRouteDraftUseCase(),
    RouteQualityCalculator qualityCalculator =
        const CalculateRouteQualityUseCase(),
    RouteGpxRepository? gpxRepository,
    DateTime Function()? clock,
  }) : _idGenerator = idGenerator,
       _routingRepository = routingRepository,
       _autosaveCoordinator = autosaveCoordinator,
       _config = config,
       _validateRoute = validateRoute,
       _qualityCalculator = qualityCalculator,
       _gpxRepository = gpxRepository,
       _clock = clock ?? DateTime.now,
       _applyEdit = ApplyRouteEditCommandUseCase(idGenerator: idGenerator) {
    if (!config.isValid) {
      throw ArgumentError.value(config, 'config', 'Invalid Route config.');
    }
  }

  final IdGenerator _idGenerator;
  final RouteRoutingRepository _routingRepository;
  final RouteDraftAutosaveCoordinator _autosaveCoordinator;
  final RouteCreateConfig _config;
  final ValidateRouteDraftUseCase _validateRoute;
  final RouteQualityCalculator _qualityCalculator;
  final RouteGpxRepository? _gpxRepository;
  final DateTime Function() _clock;
  final ApplyRouteEditCommandUseCase _applyEdit;
  final Map<String, _MutableRouteCancellationSignal> _signals =
      <String, _MutableRouteCancellationSignal>{};

  RouteCreateState? _state;
  String? _userId;
  RouteDraftData? _lastPersistedRoute;
  Timer? _autosaveTimer;

  RouteCreateState get state {
    final value = _state;
    if (value == null) {
      throw StateError('RouteCreateCoordinator is not initialized.');
    }
    return value;
  }

  void initialize({
    required String userId,
    required CreateDraftEntity createDraft,
  }) {
    final route = createDraft.routeData;
    if (userId.trim().isEmpty ||
        createDraft.objectType != CreateObjectType.route ||
        route == null) {
      throw ArgumentError('A Route draft and user id are required.');
    }
    _cancelActiveOperations();
    _autosaveTimer?.cancel();
    _userId = userId;
    _lastPersistedRoute = route;
    final preparedRoute = _withCurrentQuality(route);
    _state = RouteCreateState(
      status: RouteCreateStatus.ready,
      createDraft: createDraft.copyWith(routeData: preparedRoute),
      persistedRevision: route.revision,
      issues: _issues(preparedRoute),
    );
  }

  Future<RouteCommandOutcome> execute(RouteEditCommand command) async {
    if (command is RestorePersistedRoute) {
      return restorePersistedRevision();
    }
    final current = state;
    final before = current.route;
    _cancelActiveOperations();
    final applied = _applyEdit(
      before,
      command,
      nowUtc: _nowUtc(),
      maximumAnchors: _config.validationPolicy.maximumAnchors,
      maximumSegments: _config.validationPolicy.maximumSegments,
      maximumWaypoints: _config.validationPolicy.maximumWaypoints,
      maximumGeometryPoints: _config.validationPolicy.maximumGeometryPoints,
    );
    if (!applied.accepted) {
      _state = current.copyWith(
        status: RouteCreateStatus.failed,
        lastFailureCode: applied.failureCode?.name,
      );
      return RouteCommandOutcome(
        accepted: false,
        failureCode: applied.failureCode,
      );
    }

    final pending = _prepareRouting(applied.draft, applied.rerouteSegmentIds);
    final history = _boundedHistory(<RouteEditHistoryEntry>[
      ...current.undoStack,
      RouteEditHistoryEntry(
        command: command,
        before: before,
        after: pending.route,
      ),
    ]);
    _state = current.copyWith(
      status: pending.requests.isEmpty
          ? RouteCreateStatus.ready
          : RouteCreateStatus.routing,
      createDraft: _withRoute(current.createDraft, pending.route),
      undoStack: history,
      redoStack: const <RouteEditHistoryEntry>[],
      issues: _issues(pending.route),
      clearLastFailureCode: true,
      clearLastSaveStatus: true,
    );

    if (pending.requests.isNotEmpty) {
      await Future.wait<void>(pending.requests.map(_performRouting));
    }
    _refreshAfterOperations();
    return const RouteCommandOutcome(accepted: true);
  }

  Future<RouteCommandOutcome> importGpx(
    RouteGpxImportSelection selection, {
    required bool confirmGeometryReplacement,
  }) async {
    final repository = _gpxRepository;
    if (repository == null) {
      return const RouteCommandOutcome(
        accepted: false,
        failureCode: RouteEditFailureCode.invalidGpxImport,
      );
    }
    final startingRevision = state.route.revision;
    _state = state.copyWith(status: RouteCreateStatus.importing);
    try {
      final result = await repository.import(selection);
      if (state.route.revision != startingRevision) {
        _state = state.copyWith(status: RouteCreateStatus.ready);
        return const RouteCommandOutcome(
          accepted: false,
          failureCode: RouteEditFailureCode.invalidGpxImport,
        );
      }
      return execute(
        ApplyRouteGpxImport(
          result: result,
          confirmGeometryReplacement: confirmGeometryReplacement,
        ),
      );
    } on RouteGpxException catch (error) {
      _state = state.copyWith(
        status: RouteCreateStatus.failed,
        lastFailureCode: error.code,
      );
      return const RouteCommandOutcome(
        accepted: false,
        failureCode: RouteEditFailureCode.invalidGpxImport,
      );
    } finally {
      await repository.discard(selection.file);
    }
  }

  void synchronizeEnvelope(
    CreateDraftEntity createDraft, {
    bool scheduleAutosave = true,
  }) {
    final current = state;
    if (createDraft.objectType != CreateObjectType.route ||
        createDraft.id != current.createDraft.id) {
      throw ArgumentError('The Route envelope must keep its draft identity.');
    }
    _state = current.copyWith(
      createDraft: createDraft.copyWith(routeData: current.route),
    );
    if (scheduleAutosave) _scheduleAutosave();
  }

  bool undo() {
    final current = state;
    if (current.undoStack.isEmpty) return false;
    _cancelActiveOperations();
    final undo = <RouteEditHistoryEntry>[...current.undoStack];
    final entry = undo.removeLast();
    final restored = _applyEdit.restoreSnapshot(current.route, entry.before);
    _state = current.copyWith(
      status: RouteCreateStatus.ready,
      createDraft: _withRoute(current.createDraft, restored),
      undoStack: undo,
      redoStack: <RouteEditHistoryEntry>[
        ...current.redoStack,
        entry.copyWith(after: current.route),
      ],
      issues: _issues(restored),
      clearLastFailureCode: true,
      clearLastSaveStatus: true,
    );
    _scheduleAutosave();
    return true;
  }

  bool redo() {
    final current = state;
    if (current.redoStack.isEmpty) return false;
    _cancelActiveOperations();
    final redo = <RouteEditHistoryEntry>[...current.redoStack];
    final entry = redo.removeLast();
    final restored = _applyEdit.restoreSnapshot(current.route, entry.after);
    final history = _boundedHistory(<RouteEditHistoryEntry>[
      ...current.undoStack,
      RouteEditHistoryEntry(
        command: entry.command,
        before: current.route,
        after: restored,
      ),
    ]);
    _state = current.copyWith(
      status: RouteCreateStatus.ready,
      createDraft: _withRoute(current.createDraft, restored),
      undoStack: history,
      redoStack: redo,
      issues: _issues(restored),
      clearLastFailureCode: true,
      clearLastSaveStatus: true,
    );
    _scheduleAutosave();
    return true;
  }

  RouteCommandOutcome restorePersistedRevision() {
    final current = state;
    final persisted = _lastPersistedRoute;
    if (persisted == null || persisted.revision == current.route.revision) {
      return const RouteCommandOutcome(
        accepted: false,
        failureCode: RouteEditFailureCode.historyNoChange,
      );
    }
    _cancelActiveOperations();
    final restored = _applyEdit.restoreSnapshot(current.route, persisted);
    final history = _boundedHistory(<RouteEditHistoryEntry>[
      ...current.undoStack,
      RouteEditHistoryEntry(
        command: const RestorePersistedRoute(),
        before: current.route,
        after: restored,
      ),
    ]);
    _state = current.copyWith(
      status: RouteCreateStatus.ready,
      createDraft: _withRoute(current.createDraft, restored),
      undoStack: history,
      redoStack: const <RouteEditHistoryEntry>[],
      issues: _issues(restored),
      clearLastFailureCode: true,
    );
    _scheduleAutosave();
    return const RouteCommandOutcome(accepted: true);
  }

  Future<RouteDraftSaveResult> flushAutosave() async {
    _autosaveTimer?.cancel();
    final current = state;
    if (current.hasPendingOperations) {
      return RouteDraftSaveResult(
        status: RouteDraftSaveStatus.invalidDraft,
        requestedRevision: current.route.revision,
        persistedRevision: current.persistedRevision,
      );
    }
    _state = current.copyWith(status: RouteCreateStatus.saving);
    final result = await _autosaveCoordinator.save(
      userId: _userId!,
      draft: current.createDraft,
      expectedRevision: current.persistedRevision,
    );
    final latest = state;
    final savedRevisionIsCurrent =
        latest.route.revision == current.route.revision;
    if (result.isSaved) {
      _lastPersistedRoute = current.route;
      _state = latest.copyWith(
        status: savedRevisionIsCurrent
            ? RouteCreateStatus.saved
            : latest.status,
        persistedRevision: result.persistedRevision ?? current.route.revision,
        lastSaveStatus: result.status,
        clearLastFailureCode: savedRevisionIsCurrent,
      );
    } else {
      _state = latest.copyWith(
        status: savedRevisionIsCurrent
            ? RouteCreateStatus.failed
            : latest.status,
        lastSaveStatus: result.status,
        lastFailureCode: 'autosave_${result.status.name}',
      );
    }
    return result;
  }

  Future<void> dispose() async {
    _cancelActiveOperations();
    _autosaveTimer?.cancel();
    if (_state != null &&
        !state.hasPendingOperations &&
        state.route.revision > state.persistedRevision) {
      await flushAutosave();
    }
    await _autosaveCoordinator.waitForIdle();
  }

  _PendingRoutingBatch _prepareRouting(
    RouteDraftData route,
    List<String> segmentIds,
  ) {
    final operations = <RouteAsyncOperationDraft>[];
    final requests = <_PendingRouteRequest>[];
    for (final segmentId in segmentIds) {
      final segment = route.segmentById(segmentId);
      if (segment == null) continue;
      final from = route.anchorById(segment.fromAnchorId);
      final to = route.anchorById(segment.toAnchorId);
      if (from == null || to == null) continue;
      final operationId = _idGenerator.generate();
      final profile = segment.profileOverride ?? route.profile;
      final preferences = segment.preferencesOverride ?? route.preferences;
      final fingerprint = _fingerprint(
        from.position,
        to.position,
        profile,
        preferences,
      );
      final signal = _MutableRouteCancellationSignal();
      _signals[operationId] = signal;
      operations.add(
        RouteAsyncOperationDraft(
          operationId: operationId,
          kind: RouteAsyncOperationKind.routing,
          status: RouteAsyncOperationStatus.pending,
          expectedGeometryRevision: route.geometryRevision,
          requestFingerprint: fingerprint,
          segmentId: segment.id,
        ),
      );
      requests.add(
        _PendingRouteRequest(
          segmentId: segment.id,
          request: RouteRoutingRequest(
            operationId: operationId,
            expectedGeometryRevision: route.geometryRevision,
            requestFingerprint: fingerprint,
            from: RouteRoutingEndpoint(
              anchorId: from.id,
              position: from.position,
            ),
            to: RouteRoutingEndpoint(anchorId: to.id, position: to.position),
            profile: profile,
            preferences: preferences,
            cancellationSignal: signal,
          ),
        ),
      );
    }
    return _PendingRoutingBatch(
      route: route.copyWith(operations: operations),
      requests: requests,
    );
  }

  Future<void> _performRouting(_PendingRouteRequest pending) async {
    try {
      final result = await _routingRepository.route(pending.request);
      if (!_isCurrent(pending, result)) {
        _recordIgnoredStaleResponse();
        return;
      }
      final route = state.route;
      final from = route.anchorById(result.fromAnchorId);
      final to = route.anchorById(result.toAnchorId);
      if (from == null ||
          to == null ||
          !result.geometry.matchesCanonicalRepresentation ||
          result.geometry.points.first != from.position ||
          result.geometry.points.last != to.position) {
        _applyFailure(pending, RouteRoutingFailureCode.providerRejected);
        return;
      }
      final updated = _applyEdit.applyRoutingResult(
        route,
        RouteRoutingResultData(
          operationId: result.operationId,
          segmentId: pending.segmentId,
          geometry: result.geometry,
          provenance: result.provenance,
          providerDurationSeconds: result.providerDurationSeconds,
        ),
      );
      _replaceCurrentRoute(updated);
      _updateLatestHistoryAfter(updated);
    } on RouteRoutingException catch (error) {
      if (_hasCurrentOperation(pending)) {
        _applyFailure(pending, error.code);
      } else {
        _recordIgnoredStaleResponse();
      }
    } on Object {
      if (_hasCurrentOperation(pending)) {
        _applyFailure(pending, RouteRoutingFailureCode.unknown);
      } else {
        _recordIgnoredStaleResponse();
      }
    } finally {
      _signals.remove(pending.request.operationId);
    }
  }

  bool _isCurrent(_PendingRouteRequest pending, RouteRoutingResult result) =>
      result.operationId == pending.request.operationId &&
      result.expectedGeometryRevision ==
          pending.request.expectedGeometryRevision &&
      result.requestFingerprint == pending.request.requestFingerprint &&
      result.fromAnchorId == pending.request.from.anchorId &&
      result.toAnchorId == pending.request.to.anchorId &&
      _hasCurrentOperation(pending);

  bool _hasCurrentOperation(_PendingRouteRequest pending) {
    final route = state.route;
    final operation = _operationById(route, pending.request.operationId);
    final segment = route.segmentById(pending.segmentId);
    if (operation == null ||
        segment == null ||
        operation.status != RouteAsyncOperationStatus.pending ||
        operation.segmentId != segment.id ||
        operation.expectedGeometryRevision != route.geometryRevision ||
        operation.requestFingerprint != pending.request.requestFingerprint ||
        segment.fromAnchorId != pending.request.from.anchorId ||
        segment.toAnchorId != pending.request.to.anchorId) {
      return false;
    }
    final profile = segment.profileOverride ?? route.profile;
    final preferences = segment.preferencesOverride ?? route.preferences;
    final from = route.anchorById(segment.fromAnchorId)!;
    final to = route.anchorById(segment.toAnchorId)!;
    return _fingerprint(from.position, to.position, profile, preferences) ==
        operation.requestFingerprint;
  }

  void _applyFailure(
    _PendingRouteRequest pending,
    RouteRoutingFailureCode code,
  ) {
    final updated = _applyEdit.applyRoutingFailure(
      state.route,
      operationId: pending.request.operationId,
      segmentId: pending.segmentId,
      failureCode: code,
    );
    _replaceCurrentRoute(updated);
    _updateLatestHistoryAfter(updated);
  }

  void _replaceCurrentRoute(RouteDraftData route) {
    final current = state;
    _state = current.copyWith(
      createDraft: _withRoute(current.createDraft, route),
      issues: _issues(route),
    );
  }

  void _updateLatestHistoryAfter(RouteDraftData route) {
    final current = state;
    if (current.undoStack.isEmpty) return;
    final undo = <RouteEditHistoryEntry>[...current.undoStack];
    final latest = undo.removeLast();
    if (latest.after.geometryRevision != route.geometryRevision) return;
    undo.add(latest.copyWith(after: route));
    _state = current.copyWith(undoStack: undo);
  }

  void _refreshAfterOperations() {
    final current = state;
    if (current.hasPendingOperations) {
      _state = current.copyWith(status: RouteCreateStatus.routing);
      return;
    }
    final failed = current.route.operations.any(
      (RouteAsyncOperationDraft operation) =>
          operation.status == RouteAsyncOperationStatus.failed,
    );
    final route = failed
        ? current.route
        : _withCurrentQuality(current.route);
    _state = current.copyWith(
      status: failed ? RouteCreateStatus.failed : RouteCreateStatus.ready,
      createDraft: _withRoute(current.createDraft, route),
      issues: _issues(route),
      lastFailureCode: failed ? 'routing_failed' : null,
      clearLastFailureCode: !failed,
    );
    if (!failed) _updateLatestHistoryAfter(route);
    _scheduleAutosave();
  }

  RouteDraftData _withCurrentQuality(RouteDraftData route) {
    final quality = route.quality;
    if (quality != null &&
        quality.geometryRevision == route.geometryRevision &&
        quality.isCoherent) {
      return route;
    }
    return route.copyWith(
      quality: _qualityCalculator.calculate(
        route: route,
        calculatedAtUtc: _nowUtc(),
      ),
    );
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_config.autosaveDebounce, () {
      unawaited(flushAutosave());
    });
  }

  List<RouteEditHistoryEntry> _boundedHistory(
    List<RouteEditHistoryEntry> history,
  ) {
    var pointCount = history.fold<int>(
      0,
      (int total, RouteEditHistoryEntry entry) =>
          total +
          entry.before.geometryPointCount +
          entry.after.geometryPointCount,
    );
    while (history.length > _config.maximumHistoryEntries ||
        (history.length > _config.minimumHistoryEntries &&
            pointCount > _config.maximumHistoryGeometryPoints)) {
      final removed = history.removeAt(0);
      pointCount -=
          removed.before.geometryPointCount + removed.after.geometryPointCount;
    }
    return List<RouteEditHistoryEntry>.unmodifiable(history);
  }

  List<RouteValidationIssue> _issues(RouteDraftData route) =>
      _validateRoute(route, policy: _config.validationPolicy);

  CreateDraftEntity _withRoute(CreateDraftEntity draft, RouteDraftData route) =>
      draft.copyWith(routeData: route, updatedAtUtc: _nowUtc());

  void _cancelActiveOperations() {
    for (final signal in _signals.values) {
      signal.cancel();
    }
    _signals.clear();
  }

  void _recordIgnoredStaleResponse() {
    final current = state;
    _state = current.copyWith(
      ignoredStaleResponses: current.ignoredStaleResponses + 1,
    );
  }

  DateTime _nowUtc() => _clock().toUtc();

  static RouteAsyncOperationDraft? _operationById(
    RouteDraftData route,
    String id,
  ) {
    for (final operation in route.operations) {
      if (operation.operationId == id) return operation;
    }
    return null;
  }

  static String _fingerprint(
    GeoPoint from,
    GeoPoint to,
    RouteProfileRef profile,
    RouteRoutingPreferences preferences,
  ) {
    final preferenceKeys = preferences.values.keys.toList()..sort();
    final preferencePayload = preferenceKeys
        .map((String key) => '$key=${preferences.values[key]!.value}')
        .join('&');
    final payload = <Object>[
      'route-request-v1',
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
      profile.id,
      profile.version,
      preferences.schemaVersion,
      preferencePayload,
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString();
  }
}

class _PendingRoutingBatch {
  const _PendingRoutingBatch({required this.route, required this.requests});

  final RouteDraftData route;
  final List<_PendingRouteRequest> requests;
}

class _PendingRouteRequest {
  const _PendingRouteRequest({required this.segmentId, required this.request});

  final String segmentId;
  final RouteRoutingRequest request;
}

class _MutableRouteCancellationSignal implements RouteCancellationSignal {
  bool _cancelled = false;

  @override
  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}
