import '../../../../shared/primitives/geo/geo_distance.dart';
import '../../../../shared/primitives/geo/geo_point.dart';
import '../../../../shared/primitives/id/id_generator.dart';
import '../entities/route_draft_data.dart';
import '../entities/route_edit_command.dart';

enum RouteEditFailureCode {
  invalidCommand,
  invalidPosition,
  anchorNotFound,
  segmentNotFound,
  historyNoChange,
  geometryReplacementConfirmationRequired,
  anchorLimitReached,
  segmentLimitReached,
  waypointLimitReached,
  waypointNotFound,
  invalidFreehandGeometry,
  invalidGpxImport,
  multipleGpxTracksRequireSeparateDrafts,
  invalidGpsRecording,
  multipleGpsTracksRequireSeparateDrafts,
  sourceRequiresPreview,
  segmentsNotAdjacent,
  incompatibleSegments,
  splitPointUnavailable,
  profileInvalid,
  shapeUnavailable,
}

class RouteEditApplyResult {
  RouteEditApplyResult.accepted({
    required this.draft,
    Iterable<String> rerouteSegmentIds = const <String>[],
  }) : accepted = true,
       failureCode = null,
       rerouteSegmentIds = List<String>.unmodifiable(rerouteSegmentIds);

  const RouteEditApplyResult.rejected({
    required this.draft,
    required this.failureCode,
  }) : accepted = false,
       rerouteSegmentIds = const <String>[];

  final bool accepted;
  final RouteDraftData draft;
  final RouteEditFailureCode? failureCode;
  final List<String> rerouteSegmentIds;
}

class ApplyRouteEditCommandUseCase {
  const ApplyRouteEditCommandUseCase({required IdGenerator idGenerator})
    : _idGenerator = idGenerator;

  final IdGenerator _idGenerator;

  RouteEditApplyResult call(
    RouteDraftData draft,
    RouteEditCommand command, {
    required DateTime nowUtc,
    required int maximumAnchors,
    required int maximumSegments,
    required int maximumWaypoints,
    required int maximumGeometryPoints,
  }) {
    if (!nowUtc.isUtc ||
        maximumAnchors < 2 ||
        maximumSegments < 1 ||
        maximumWaypoints < 0 ||
        maximumGeometryPoints < 2) {
      return _reject(draft, RouteEditFailureCode.invalidCommand);
    }
    return switch (command) {
      SelectRouteCreationMethod() => _selectMethod(draft, command, nowUtc),
      ApplyRouteFreehandGeometry() => _applyFreehand(
        draft,
        command,
        nowUtc,
        maximumGeometryPoints,
      ),
      ApplyRouteGpxImport() => _applyGpx(
        draft,
        command,
        nowUtc,
        maximumWaypoints,
        maximumGeometryPoints,
      ),
      ApplyRouteGpsRecording() => _applyGps(
        draft,
        command,
        nowUtc,
        maximumGeometryPoints,
      ),
      AddRouteAnchor() => _addAnchor(
        draft,
        command,
        nowUtc,
        maximumAnchors,
        maximumSegments,
      ),
      MoveRouteAnchor() => _moveAnchor(draft, command, nowUtc),
      RemoveRouteAnchor() => _removeAnchor(
        draft,
        command,
        nowUtc,
        maximumSegments,
      ),
      SplitRouteSegment() => _splitSegment(
        draft,
        command,
        nowUtc,
        maximumAnchors,
        maximumSegments,
      ),
      MergeRouteSegments() => _mergeSegments(draft, command, nowUtc),
      ChangeRouteProfile() => _changeProfile(draft, command, nowUtc),
      ChangeRouteShape() => _changeShape(
        draft,
        command,
        nowUtc,
        maximumSegments,
      ),
      ChangeRouteSegmentProfile() => _changeSegmentProfile(
        draft,
        command,
        nowUtc,
      ),
      SetRouteSegmentDirect() => _setDirect(draft, command, nowUtc),
      RerouteRouteSegment() => _reroute(draft, command.segmentId, nowUtc),
      RetryRouteSegment() => _reroute(draft, command.segmentId, nowUtc),
      AddRouteWaypoint() => _addWaypoint(
        draft,
        command,
        nowUtc,
        maximumWaypoints,
      ),
      MoveRouteWaypoint() => _moveWaypoint(draft, command, nowUtc),
      RemoveRouteWaypoint() => _removeWaypoint(draft, command, nowUtc),
      ChangeRouteConditions() => _changeConditions(draft, command, nowUtc),
      RestorePersistedRoute() => _reject(
        draft,
        RouteEditFailureCode.invalidCommand,
      ),
    };
  }

  RouteEditApplyResult _applyGpx(
    RouteDraftData draft,
    ApplyRouteGpxImport command,
    DateTime nowUtc,
    int maximumWaypoints,
    int maximumGeometryPoints,
  ) {
    if (draft.segments.isNotEmpty && !command.confirmGeometryReplacement) {
      return _reject(
        draft,
        RouteEditFailureCode.geometryReplacementConfirmationRequired,
      );
    }
    if (command.result.tracks.length != 1) {
      return _reject(
        draft,
        RouteEditFailureCode.multipleGpxTracksRequireSeparateDrafts,
      );
    }
    final points = <GeoPoint>[];
    for (final point in command.result.tracks.single) {
      if (!point.isValid) {
        return _reject(draft, RouteEditFailureCode.invalidGpxImport);
      }
      if (points.isEmpty || points.last != point) points.add(point);
    }
    if (points.length < 2 ||
        points.length > maximumGeometryPoints ||
        command.result.waypoints.length > maximumWaypoints) {
      return _reject(draft, RouteEditFailureCode.invalidGpxImport);
    }
    final first = RouteAnchorDraft(id: _localId(), position: points.first);
    final last = RouteAnchorDraft(id: _localId(), position: points.last);
    final geometry = RouteGeometryDraft.fromPoints(
      points,
      encodingPolicy: draft.encodingPolicy,
    );
    final segmentId = _localId();
    final segment = RouteSegmentDraft(
      id: segmentId,
      fromAnchorId: first.id,
      toAnchorId: last.id,
      order: 0,
      source: RouteSegmentSource.importedGpx,
      derivation: RouteSegmentDerivation.original,
      geometry: geometry,
      provenance: command.result.provenance,
      geometryRevision: draft.geometryRevision + 1,
      rawStats: RouteSegmentRawStats(distanceMeters: geometry.lengthMeters),
    );
    final waypoints = command.result.waypoints
        .map(
          (waypoint) => RouteWaypointDraft(
            id: _localId(),
            segmentId: waypoint.trackState == RouteWaypointTrackState.unresolved
                ? null
                : segmentId,
            position: waypoint.position,
            typeId: waypoint.typeId,
            trackState: waypoint.trackState,
            title: waypoint.name,
            note: waypoint.note,
          ),
        )
        .toList(growable: false);
    final issues = command.result.sourceIssues
        .map(
          (issue) => RouteSourceIssueDraft(
            id: _localId(),
            code: issue.code,
            severity: issue.severity,
            segmentId: issue.segmentId == null ? null : segmentId,
            safeMetrics: issue.safeMetrics,
          ),
        )
        .toList(growable: false);
    return _accepted(
      draft,
      nowUtc,
      creationMethod: RouteCreationMethod.importedGpx,
      shape: RouteShape.oneWay,
      clearTurningAnchorId: true,
      anchors: <RouteAnchorDraft>[first, last],
      segments: <RouteSegmentDraft>[segment],
      waypoints: waypoints,
      sourceIssues: issues,
    );
  }

  RouteEditApplyResult _applyGps(
    RouteDraftData draft,
    ApplyRouteGpsRecording command,
    DateTime nowUtc,
    int maximumGeometryPoints,
  ) {
    if (draft.segments.isNotEmpty && !command.confirmGeometryReplacement) {
      return _reject(
        draft,
        RouteEditFailureCode.geometryReplacementConfirmationRequired,
      );
    }
    if (command.result.tracks.length != 1) {
      return _reject(
        draft,
        RouteEditFailureCode.multipleGpsTracksRequireSeparateDrafts,
      );
    }
    final points = <GeoPoint>[];
    for (final point in command.result.tracks.single) {
      if (!point.isValid) {
        return _reject(draft, RouteEditFailureCode.invalidGpsRecording);
      }
      if (points.isEmpty || points.last != point) points.add(point);
    }
    if (points.length < 2 ||
        points.length > maximumGeometryPoints ||
        !command.result.provenance.isValid ||
        !command.result.rawStats.isValid) {
      return _reject(draft, RouteEditFailureCode.invalidGpsRecording);
    }
    final first = RouteAnchorDraft(id: _localId(), position: points.first);
    final last = RouteAnchorDraft(id: _localId(), position: points.last);
    final geometry = RouteGeometryDraft.fromPoints(
      points,
      encodingPolicy: draft.encodingPolicy,
    );
    final segmentId = _localId();
    final segment = RouteSegmentDraft(
      id: segmentId,
      fromAnchorId: first.id,
      toAnchorId: last.id,
      order: 0,
      source: RouteSegmentSource.recordedGps,
      derivation: RouteSegmentDerivation.original,
      geometry: geometry,
      provenance: command.result.provenance,
      geometryRevision: draft.geometryRevision + 1,
      rawStats: command.result.rawStats,
      needsReview: command.result.sourceIssues.isNotEmpty,
    );
    final issues = command.result.sourceIssues
        .map(
          (issue) => RouteSourceIssueDraft(
            id: _localId(),
            code: issue.code,
            severity: issue.severity,
            segmentId: segmentId,
            safeMetrics: issue.safeMetrics,
          ),
        )
        .toList(growable: false);
    return _accepted(
      draft,
      nowUtc,
      creationMethod: RouteCreationMethod.recordedGps,
      shape: RouteShape.oneWay,
      clearTurningAnchorId: true,
      anchors: <RouteAnchorDraft>[first, last],
      segments: <RouteSegmentDraft>[segment],
      waypoints: const <RouteWaypointDraft>[],
      sourceIssues: issues,
    );
  }

  RouteEditApplyResult _applyFreehand(
    RouteDraftData draft,
    ApplyRouteFreehandGeometry command,
    DateTime nowUtc,
    int maximumGeometryPoints,
  ) {
    final points = <GeoPoint>[];
    for (final point in command.points) {
      if (!point.isValid) {
        return _reject(draft, RouteEditFailureCode.invalidPosition);
      }
      if (points.isEmpty || points.last != point) points.add(point);
    }
    if (points.length < 2 ||
        points.length > maximumGeometryPoints ||
        points.first == points.last) {
      return _reject(draft, RouteEditFailureCode.invalidFreehandGeometry);
    }
    if (draft.segments.isNotEmpty && !command.confirmGeometryReplacement) {
      return _reject(
        draft,
        RouteEditFailureCode.geometryReplacementConfirmationRequired,
      );
    }
    final first = RouteAnchorDraft(id: _localId(), position: points.first);
    final last = RouteAnchorDraft(id: _localId(), position: points.last);
    final geometry = RouteGeometryDraft.fromPoints(
      points,
      encodingPolicy: draft.encodingPolicy,
    );
    final segment = RouteSegmentDraft(
      id: _localId(),
      fromAnchorId: first.id,
      toAnchorId: last.id,
      order: 0,
      source: RouteSegmentSource.freehand,
      derivation: RouteSegmentDerivation.original,
      geometry: geometry,
      provenance: RouteProvenanceDraft(
        sourceId: 'author-freehand',
        sourceRevision: draft.revision + 1,
        createdAtUtc: nowUtc,
        algorithmVersion: 'freehand-v1',
      ),
      geometryRevision: draft.geometryRevision + 1,
      rawStats: RouteSegmentRawStats(distanceMeters: geometry.lengthMeters),
    );
    return _accepted(
      draft,
      nowUtc,
      creationMethod: RouteCreationMethod.freehand,
      shape: RouteShape.oneWay,
      clearTurningAnchorId: true,
      anchors: <RouteAnchorDraft>[first, last],
      segments: <RouteSegmentDraft>[segment],
      waypoints: draft.waypoints
          .map(_unresolveWaypoint)
          .toList(growable: false),
    );
  }

  RouteDraftData applyRoutingResult(
    RouteDraftData draft,
    RouteRoutingResultData result,
  ) {
    final segment = draft.segmentById(result.segmentId);
    if (segment == null) return draft;
    final segments = draft.segments
        .map(
          (RouteSegmentDraft value) => value.id == result.segmentId
              ? value.copyWith(
                  source: RouteSegmentSource.routed,
                  derivation: segment.derivation,
                  geometry: result.geometry,
                  provenance: result.provenance,
                  operationState: RouteSegmentOperationState.ready,
                  rawStats: RouteSegmentRawStats(
                    distanceMeters: result.geometry.lengthMeters,
                  ),
                  providerDurationSeconds: result.providerDurationSeconds,
                  clearFallbackReason: true,
                  needsReview: false,
                )
              : value,
        )
        .toList(growable: false);
    return draft.copyWith(
      segments: segments,
      operations: draft.operations
          .where(
            (RouteAsyncOperationDraft operation) =>
                operation.operationId != result.operationId,
          )
          .toList(growable: false),
      metrics: _metricsFor(
        draft.metrics,
        segments,
        draft.geometryRevision,
        draft.conditions,
      ),
    );
  }

  RouteDraftData applyRoutingFailure(
    RouteDraftData draft, {
    required String operationId,
    required String segmentId,
    required RouteRoutingFailureCode failureCode,
  }) => draft.copyWith(
    segments: draft.segments
        .map(
          (RouteSegmentDraft segment) => segment.id == segmentId
              ? segment.copyWith(
                  operationState: RouteSegmentOperationState.failed,
                  fallbackReason: failureCode,
                  needsReview: true,
                )
              : segment,
        )
        .toList(growable: false),
    operations: draft.operations
        .map(
          (RouteAsyncOperationDraft operation) =>
              operation.operationId == operationId
              ? RouteAsyncOperationDraft(
                  operationId: operation.operationId,
                  kind: operation.kind,
                  status: RouteAsyncOperationStatus.failed,
                  expectedGeometryRevision: operation.expectedGeometryRevision,
                  requestFingerprint: operation.requestFingerprint,
                  segmentId: operation.segmentId,
                  failureCode: failureCode.name,
                )
              : operation,
        )
        .toList(growable: false),
  );

  RouteDraftData restoreSnapshot(
    RouteDraftData current,
    RouteDraftData snapshot,
  ) {
    final geometryRevision = current.geometryRevision + 1;
    final segments = snapshot.segments
        .map(
          (RouteSegmentDraft segment) => segment.copyWith(
            geometryRevision: geometryRevision,
            operationState: RouteSegmentOperationState.ready,
          ),
        )
        .toList(growable: false);
    return snapshot.copyWith(
      revision: current.revision + 1,
      geometryRevision: geometryRevision,
      segments: segments,
      operations: const <RouteAsyncOperationDraft>[],
      metrics: _metricsFor(
        snapshot.metrics,
        segments,
        geometryRevision,
        snapshot.conditions,
      ),
    );
  }

  RouteEditApplyResult _selectMethod(
    RouteDraftData draft,
    SelectRouteCreationMethod command,
    DateTime nowUtc,
  ) {
    if (draft.creationMethod == command.method) {
      return _reject(draft, RouteEditFailureCode.historyNoChange);
    }
    if (draft.segments.isNotEmpty && !command.confirmGeometryReplacement) {
      return _reject(
        draft,
        RouteEditFailureCode.geometryReplacementConfirmationRequired,
      );
    }
    if (draft.segments.isEmpty) {
      return _accepted(draft, nowUtc, creationMethod: command.method);
    }
    return _accepted(
      draft,
      nowUtc,
      creationMethod: command.method,
      anchors: const <RouteAnchorDraft>[],
      segments: const <RouteSegmentDraft>[],
      waypoints: draft.waypoints
          .map(_unresolveWaypoint)
          .toList(growable: false),
    );
  }

  RouteEditApplyResult _addAnchor(
    RouteDraftData draft,
    AddRouteAnchor command,
    DateTime nowUtc,
    int maximumAnchors,
    int maximumSegments,
  ) {
    if (!command.position.isValid) {
      return _reject(draft, RouteEditFailureCode.invalidPosition);
    }
    if (draft.anchors.length >= maximumAnchors) {
      return _reject(draft, RouteEditFailureCode.anchorLimitReached);
    }

    final anchor = RouteAnchorDraft(
      id: _localId(),
      position: command.position,
      authorIntentId: command.authorIntentId,
    );
    if (draft.anchors.isEmpty) {
      return _accepted(draft, nowUtc, anchors: <RouteAnchorDraft>[anchor]);
    }
    if (draft.segments.length >= maximumSegments) {
      return _reject(draft, RouteEditFailureCode.segmentLimitReached);
    }

    return switch (draft.shape) {
      RouteShape.oneWay => _addOneWayAnchor(draft, anchor, nowUtc),
      RouteShape.loop => _addLoopAnchor(draft, anchor, nowUtc, maximumSegments),
      RouteShape.outAndBack => _addOutAndBackAnchor(
        draft,
        anchor,
        nowUtc,
        maximumSegments,
      ),
    };
  }

  RouteEditApplyResult _addOneWayAnchor(
    RouteDraftData draft,
    RouteAnchorDraft anchor,
    DateTime nowUtc,
  ) {
    final previous = draft.orderedSegments.isEmpty
        ? draft.anchors.last
        : draft.anchorById(draft.orderedSegments.last.toAnchorId)!;
    final segment = _pendingSegment(
      id: _localId(),
      from: previous,
      to: anchor,
      order: draft.segments.length,
      draft: draft,
      nowUtc: nowUtc,
    );
    return _accepted(
      draft,
      nowUtc,
      anchors: <RouteAnchorDraft>[...draft.anchors, anchor],
      segments: <RouteSegmentDraft>[...draft.orderedSegments, segment],
      rerouteSegmentIds: <String>[segment.id],
    );
  }

  RouteEditApplyResult _addLoopAnchor(
    RouteDraftData draft,
    RouteAnchorDraft anchor,
    DateTime nowUtc,
    int maximumSegments,
  ) {
    final ordered = draft.orderedSegments;
    if (ordered.isEmpty) {
      return _reject(draft, RouteEditFailureCode.shapeUnavailable);
    }
    if (ordered.length + 1 > maximumSegments) {
      return _reject(draft, RouteEditFailureCode.segmentLimitReached);
    }
    final closing = ordered.last;
    if (!_canReshape(closing)) {
      return _reject(draft, RouteEditFailureCode.sourceRequiresPreview);
    }
    final from = draft.anchorById(closing.fromAnchorId)!;
    final to = draft.anchorById(closing.toAnchorId)!;
    final first = _replacementSegment(
      template: closing,
      id: _localId(),
      from: from,
      to: anchor,
      order: closing.order,
      draft: draft,
      nowUtc: nowUtc,
    );
    final second = _replacementSegment(
      template: closing,
      id: _localId(),
      from: anchor,
      to: to,
      order: closing.order + 1,
      draft: draft,
      nowUtc: nowUtc,
    );
    final rerouteIds = <String>[
      if (!_isDirect(first)) first.id,
      if (!_isDirect(second)) second.id,
    ];
    return _accepted(
      draft,
      nowUtc,
      anchors: <RouteAnchorDraft>[...draft.anchors, anchor],
      segments: <RouteSegmentDraft>[
        ...ordered.take(ordered.length - 1),
        first,
        second,
      ],
      waypoints: _unresolveWaypointsFor(
        draft,
        removedAnchorId: null,
        removedSegmentIds: <String>{closing.id},
      ),
      rerouteSegmentIds: rerouteIds,
    );
  }

  RouteEditApplyResult _addOutAndBackAnchor(
    RouteDraftData draft,
    RouteAnchorDraft anchor,
    DateTime nowUtc,
    int maximumSegments,
  ) {
    final outward = _outwardSegments(draft);
    if (outward.isEmpty || draft.turningAnchorId == null) {
      return _reject(draft, RouteEditFailureCode.shapeUnavailable);
    }
    if (draft.segments.length + 2 > maximumSegments) {
      return _reject(draft, RouteEditFailureCode.segmentLimitReached);
    }
    final turning = draft.anchorById(draft.turningAnchorId!);
    if (turning == null) {
      return _reject(draft, RouteEditFailureCode.shapeUnavailable);
    }
    final outwardTemplate = outward.last;
    final returnSegments = draft.orderedSegments
        .skip(outward.length)
        .toList(growable: false);
    final returnTemplate = returnSegments.isEmpty
        ? outwardTemplate
        : returnSegments.first;
    final extension = _replacementSegment(
      template: outwardTemplate,
      id: _localId(),
      from: turning,
      to: anchor,
      order: outward.length,
      draft: draft,
      nowUtc: nowUtc,
      derivation: RouteSegmentDerivation.original,
    );
    final mirrored = _replacementSegment(
      template: returnTemplate,
      id: _localId(),
      from: anchor,
      to: turning,
      order: outward.length + 1,
      draft: draft,
      nowUtc: nowUtc,
      derivation: RouteSegmentDerivation.mirrored,
    );
    final segments =
        <RouteSegmentDraft>[...outward, extension, mirrored, ...returnSegments]
            .asMap()
            .entries
            .map(
              (MapEntry<int, RouteSegmentDraft> entry) =>
                  entry.value.copyWith(order: entry.key),
            )
            .toList(growable: false);
    return _accepted(
      draft,
      nowUtc,
      anchors: <RouteAnchorDraft>[...draft.anchors, anchor],
      segments: segments,
      turningAnchorId: anchor.id,
      rerouteSegmentIds: <String>[
        if (!_isDirect(extension)) extension.id,
        if (!_isDirect(mirrored)) mirrored.id,
      ],
    );
  }

  RouteEditApplyResult _moveAnchor(
    RouteDraftData draft,
    MoveRouteAnchor command,
    DateTime nowUtc,
  ) {
    if (!command.position.isValid) {
      return _reject(draft, RouteEditFailureCode.invalidPosition);
    }
    final anchor = draft.anchorById(command.anchorId);
    if (anchor == null) {
      return _reject(draft, RouteEditFailureCode.anchorNotFound);
    }
    if (anchor.position == command.position) {
      return _reject(draft, RouteEditFailureCode.historyNoChange);
    }

    final anchors = draft.anchors
        .map(
          (RouteAnchorDraft value) => value.id == command.anchorId
              ? value.copyWith(position: command.position)
              : value,
        )
        .toList(growable: false);
    final anchorById = <String, RouteAnchorDraft>{
      for (final value in anchors) value.id: value,
    };
    final affected = draft.segments
        .where(
          (RouteSegmentDraft segment) =>
              segment.fromAnchorId == command.anchorId ||
              segment.toAnchorId == command.anchorId,
        )
        .toList(growable: false);
    if (affected.any((RouteSegmentDraft segment) => !_canReshape(segment))) {
      return _reject(draft, RouteEditFailureCode.sourceRequiresPreview);
    }

    final rerouteIds = <String>[];
    final segments = draft.orderedSegments
        .map((RouteSegmentDraft segment) {
          if (!affected.contains(segment)) return segment;
          final from = anchorById[segment.fromAnchorId]!;
          final to = anchorById[segment.toAnchorId]!;
          if (_isDirect(segment)) {
            return _directCopy(segment, from, to, draft, nowUtc);
          }
          rerouteIds.add(segment.id);
          return _pendingCopy(segment, from, to, draft, nowUtc);
        })
        .toList(growable: false);

    return _accepted(
      draft,
      nowUtc,
      anchors: anchors,
      segments: segments,
      rerouteSegmentIds: rerouteIds,
    );
  }

  RouteEditApplyResult _removeAnchor(
    RouteDraftData draft,
    RemoveRouteAnchor command,
    DateTime nowUtc,
    int maximumSegments,
  ) {
    final anchorIndex = draft.anchors.indexWhere(
      (RouteAnchorDraft anchor) => anchor.id == command.anchorId,
    );
    if (anchorIndex < 0) {
      return _reject(draft, RouteEditFailureCode.anchorNotFound);
    }
    final touching = draft.orderedSegments
        .where(
          (RouteSegmentDraft segment) =>
              segment.fromAnchorId == command.anchorId ||
              segment.toAnchorId == command.anchorId,
        )
        .toList(growable: false);
    if (touching.any((RouteSegmentDraft segment) => !_canReshape(segment))) {
      return _reject(draft, RouteEditFailureCode.sourceRequiresPreview);
    }
    if (draft.shape == RouteShape.outAndBack) {
      return _removeOutAndBackAnchor(
        draft,
        command,
        touching,
        nowUtc,
        maximumSegments,
      );
    }
    if (touching.length > 2) {
      return _reject(draft, RouteEditFailureCode.shapeUnavailable);
    }

    final anchors = <RouteAnchorDraft>[
      ...draft.anchors.where(
        (RouteAnchorDraft anchor) => anchor.id != command.anchorId,
      ),
    ];
    final removedSegmentIds = touching
        .map((RouteSegmentDraft segment) => segment.id)
        .toSet();
    final kept = draft.orderedSegments
        .where(
          (RouteSegmentDraft segment) =>
              !removedSegmentIds.contains(segment.id),
        )
        .toList(growable: true);
    final rerouteIds = <String>[];

    if (touching.length == 2 && anchors.length >= 2) {
      if (kept.length >= maximumSegments) {
        return _reject(draft, RouteEditFailureCode.segmentLimitReached);
      }
      final incoming = touching.firstWhere(
        (RouteSegmentDraft segment) => segment.toAnchorId == command.anchorId,
      );
      final outgoing = touching.firstWhere(
        (RouteSegmentDraft segment) => segment.fromAnchorId == command.anchorId,
      );
      final from = draft.anchorById(incoming.fromAnchorId)!;
      final to = draft.anchorById(outgoing.toAnchorId)!;
      if (from.id != to.id) {
        if (!_canJoinAutomatically(incoming, outgoing)) {
          return _reject(draft, RouteEditFailureCode.incompatibleSegments);
        }
        final replacement = _replacementFromPair(
          incoming: incoming,
          outgoing: outgoing,
          from: from,
          to: to,
          order: incoming.order,
          draft: draft,
          nowUtc: nowUtc,
        );
        kept.add(replacement);
        if (!_isDirect(replacement)) rerouteIds.add(replacement.id);
      }
    }
    kept.sort(
      (RouteSegmentDraft left, RouteSegmentDraft right) =>
          left.order.compareTo(right.order),
    );
    final segments = kept
        .asMap()
        .entries
        .map(
          (MapEntry<int, RouteSegmentDraft> entry) =>
              entry.value.copyWith(order: entry.key),
        )
        .toList(growable: false);
    final waypoints = _unresolveWaypointsFor(
      draft,
      removedAnchorId: command.anchorId,
      removedSegmentIds: removedSegmentIds,
    );

    return _accepted(
      draft,
      nowUtc,
      anchors: anchors,
      segments: segments,
      waypoints: waypoints,
      rerouteSegmentIds: rerouteIds,
    );
  }

  RouteEditApplyResult _removeOutAndBackAnchor(
    RouteDraftData draft,
    RemoveRouteAnchor command,
    List<RouteSegmentDraft> touching,
    DateTime nowUtc,
    int maximumSegments,
  ) {
    final anchors = draft.anchors
        .where((RouteAnchorDraft anchor) => anchor.id != command.anchorId)
        .toList(growable: false);
    final removedSegmentIds = touching
        .map((RouteSegmentDraft segment) => segment.id)
        .toSet();
    final kept = draft.orderedSegments
        .where(
          (RouteSegmentDraft segment) =>
              !removedSegmentIds.contains(segment.id),
        )
        .toList(growable: true);
    final replacements = <RouteSegmentDraft>[];
    final rerouteIds = <String>[];

    if (anchors.length >= 2 && touching.length == 2) {
      final incoming = touching.firstWhere(
        (RouteSegmentDraft segment) => segment.toAnchorId == command.anchorId,
      );
      final outgoing = touching.firstWhere(
        (RouteSegmentDraft segment) => segment.fromAnchorId == command.anchorId,
      );
      final from = draft.anchorById(incoming.fromAnchorId)!;
      final to = draft.anchorById(outgoing.toAnchorId)!;
      if (from.id != to.id) {
        if (!_canJoinAutomatically(incoming, outgoing)) {
          return _reject(draft, RouteEditFailureCode.incompatibleSegments);
        }
        replacements.add(
          _replacementFromPair(
            incoming: incoming,
            outgoing: outgoing,
            from: from,
            to: to,
            order: incoming.order,
            draft: draft,
            nowUtc: nowUtc,
          ),
        );
      }
    } else if (anchors.length >= 2 && touching.length == 4) {
      final outward = _outwardSegments(draft);
      final returning = draft.orderedSegments
          .skip(outward.length)
          .toList(growable: false);
      final outwardIncoming = outward.firstWhere(
        (RouteSegmentDraft segment) => segment.toAnchorId == command.anchorId,
      );
      final outwardOutgoing = outward.firstWhere(
        (RouteSegmentDraft segment) => segment.fromAnchorId == command.anchorId,
      );
      final returnIncoming = returning.firstWhere(
        (RouteSegmentDraft segment) => segment.toAnchorId == command.anchorId,
      );
      final returnOutgoing = returning.firstWhere(
        (RouteSegmentDraft segment) => segment.fromAnchorId == command.anchorId,
      );
      if (!_canJoinAutomatically(outwardIncoming, outwardOutgoing) ||
          !_canJoinAutomatically(returnIncoming, returnOutgoing)) {
        return _reject(draft, RouteEditFailureCode.incompatibleSegments);
      }
      replacements
        ..add(
          _replacementFromPair(
            incoming: outwardIncoming,
            outgoing: outwardOutgoing,
            from: draft.anchorById(outwardIncoming.fromAnchorId)!,
            to: draft.anchorById(outwardOutgoing.toAnchorId)!,
            order: outwardIncoming.order,
            draft: draft,
            nowUtc: nowUtc,
          ),
        )
        ..add(
          _replacementFromPair(
            incoming: returnIncoming,
            outgoing: returnOutgoing,
            from: draft.anchorById(returnIncoming.fromAnchorId)!,
            to: draft.anchorById(returnOutgoing.toAnchorId)!,
            order: returnIncoming.order,
            draft: draft,
            nowUtc: nowUtc,
            derivation: RouteSegmentDerivation.mirrored,
          ),
        );
    } else if (anchors.length >= 2 && touching.isNotEmpty) {
      return _reject(draft, RouteEditFailureCode.shapeUnavailable);
    }

    if (kept.length + replacements.length > maximumSegments) {
      return _reject(draft, RouteEditFailureCode.segmentLimitReached);
    }
    kept.addAll(replacements);
    kept.sort(
      (RouteSegmentDraft left, RouteSegmentDraft right) =>
          left.order.compareTo(right.order),
    );
    final segments = kept
        .asMap()
        .entries
        .map(
          (MapEntry<int, RouteSegmentDraft> entry) =>
              entry.value.copyWith(order: entry.key),
        )
        .toList(growable: false);
    rerouteIds.addAll(
      replacements
          .where((RouteSegmentDraft segment) => !_isDirect(segment))
          .map((RouteSegmentDraft segment) => segment.id),
    );

    String? turningAnchorId = draft.turningAnchorId;
    var clearTurningAnchorId = false;
    if (anchors.length < 2) {
      turningAnchorId = null;
      clearTurningAnchorId = true;
    } else if (draft.turningAnchorId == command.anchorId) {
      final incoming = touching.firstWhere(
        (RouteSegmentDraft segment) => segment.toAnchorId == command.anchorId,
      );
      turningAnchorId = incoming.fromAnchorId;
    }

    return _accepted(
      draft,
      nowUtc,
      anchors: anchors,
      segments: segments,
      waypoints: _unresolveWaypointsFor(
        draft,
        removedAnchorId: command.anchorId,
        removedSegmentIds: removedSegmentIds,
      ),
      turningAnchorId: turningAnchorId,
      clearTurningAnchorId: clearTurningAnchorId,
      rerouteSegmentIds: rerouteIds,
    );
  }

  RouteEditApplyResult _splitSegment(
    RouteDraftData draft,
    SplitRouteSegment command,
    DateTime nowUtc,
    int maximumAnchors,
    int maximumSegments,
  ) {
    final segment = draft.segmentById(command.segmentId);
    if (segment == null) {
      return _reject(draft, RouteEditFailureCode.segmentNotFound);
    }
    if (!command.position.isValid) {
      return _reject(draft, RouteEditFailureCode.invalidPosition);
    }
    if (draft.anchors.length >= maximumAnchors) {
      return _reject(draft, RouteEditFailureCode.anchorLimitReached);
    }
    if (draft.segments.length >= maximumSegments) {
      return _reject(draft, RouteEditFailureCode.segmentLimitReached);
    }
    if (segment.geometry.points.length < 3) {
      return _reject(draft, RouteEditFailureCode.splitPointUnavailable);
    }

    final splitIndex = _nearestInteriorPointIndex(
      segment.geometry.points,
      command.position,
    );
    if (splitIndex == null) {
      return _reject(draft, RouteEditFailureCode.splitPointUnavailable);
    }
    final splitPoint = segment.geometry.points[splitIndex];
    final anchor = RouteAnchorDraft(id: _localId(), position: splitPoint);
    final first = segment.copyWith(
      id: _localId(),
      toAnchorId: anchor.id,
      geometry: RouteGeometryDraft.fromPoints(
        segment.geometry.points.sublist(0, splitIndex + 1),
        encodingPolicy: draft.encodingPolicy,
      ),
      provenance: _derivedProvenance(segment, nowUtc),
    );
    final second = segment.copyWith(
      id: _localId(),
      fromAnchorId: anchor.id,
      order: segment.order + 1,
      geometry: RouteGeometryDraft.fromPoints(
        segment.geometry.points.sublist(splitIndex),
        encodingPolicy: draft.encodingPolicy,
      ),
      provenance: _derivedProvenance(segment, nowUtc),
    );
    final segments = <RouteSegmentDraft>[];
    for (final value in draft.orderedSegments) {
      if (value.id == segment.id) {
        segments
          ..add(first)
          ..add(second);
      } else {
        segments.add(value);
      }
    }
    final normalized = segments
        .asMap()
        .entries
        .map(
          (MapEntry<int, RouteSegmentDraft> entry) =>
              entry.value.copyWith(order: entry.key),
        )
        .toList(growable: false);
    final waypoints = draft.waypoints
        .map((RouteWaypointDraft waypoint) {
          if (waypoint.segmentId != segment.id) return waypoint;
          final onFirst =
              (waypoint.distanceFromStartMeters ?? double.infinity) <=
              first.distanceMeters;
          return _copyWaypoint(
            waypoint,
            segmentId: onFirst ? first.id : second.id,
            distanceFromStartMeters: waypoint.distanceFromStartMeters,
          );
        })
        .toList(growable: false);

    return _accepted(
      draft,
      nowUtc,
      anchors: _insertAnchorAfter(
        draft.anchors,
        afterAnchorId: segment.fromAnchorId,
        anchor: anchor,
      ),
      segments: normalized,
      waypoints: waypoints,
    );
  }

  RouteEditApplyResult _mergeSegments(
    RouteDraftData draft,
    MergeRouteSegments command,
    DateTime nowUtc,
  ) {
    final first = draft.segmentById(command.firstSegmentId);
    final second = draft.segmentById(command.secondSegmentId);
    if (first == null || second == null) {
      return _reject(draft, RouteEditFailureCode.segmentNotFound);
    }
    if (first.toAnchorId != second.fromAnchorId ||
        second.order != first.order + 1) {
      return _reject(draft, RouteEditFailureCode.segmentsNotAdjacent);
    }
    if (!_compatibleForMerge(first, second)) {
      return _reject(draft, RouteEditFailureCode.incompatibleSegments);
    }
    final points = <GeoPoint>[
      ...first.geometry.points,
      ...second.geometry.points.skip(1),
    ];
    final merged = first.copyWith(
      id: _localId(),
      toAnchorId: second.toAnchorId,
      geometry: RouteGeometryDraft.fromPoints(
        points,
        encodingPolicy: draft.encodingPolicy,
      ),
      provenance: _derivedProvenance(first, nowUtc),
    );
    final removedAnchorId = first.toAnchorId;
    final segments = <RouteSegmentDraft>[];
    for (final segment in draft.orderedSegments) {
      if (segment.id == first.id) {
        segments.add(merged);
      } else if (segment.id != second.id) {
        segments.add(segment);
      }
    }
    final normalized = segments
        .asMap()
        .entries
        .map(
          (MapEntry<int, RouteSegmentDraft> entry) =>
              entry.value.copyWith(order: entry.key),
        )
        .toList(growable: false);
    final stillReferenced = normalized.any(
      (RouteSegmentDraft segment) =>
          segment.fromAnchorId == removedAnchorId ||
          segment.toAnchorId == removedAnchorId,
    );
    final anchors = stillReferenced
        ? draft.anchors
        : draft.anchors
              .where((RouteAnchorDraft anchor) => anchor.id != removedAnchorId)
              .toList(growable: false);
    final waypoints = draft.waypoints
        .map((RouteWaypointDraft waypoint) {
          if (waypoint.segmentId == first.id) {
            return _copyWaypoint(waypoint, segmentId: merged.id);
          }
          if (waypoint.segmentId == second.id) {
            return _copyWaypoint(
              waypoint,
              segmentId: merged.id,
              distanceFromStartMeters:
                  first.distanceMeters +
                  (waypoint.distanceFromStartMeters ?? 0),
            );
          }
          return waypoint;
        })
        .toList(growable: false);

    return _accepted(
      draft,
      nowUtc,
      anchors: anchors,
      segments: normalized,
      waypoints: waypoints,
    );
  }

  RouteEditApplyResult _changeProfile(
    RouteDraftData draft,
    ChangeRouteProfile command,
    DateTime nowUtc,
  ) {
    if (!command.profile.isValid ||
        (command.preferences != null && !command.preferences!.isValid)) {
      return _reject(draft, RouteEditFailureCode.profileInvalid);
    }
    if (draft.profile.id == command.profile.id &&
        draft.profile.version == command.profile.version &&
        command.preferences == null) {
      return _reject(draft, RouteEditFailureCode.historyNoChange);
    }
    final rerouteIds = <String>[];
    final segments = draft.orderedSegments
        .map((RouteSegmentDraft segment) {
          if (!_isRoutable(segment)) return segment;
          rerouteIds.add(segment.id);
          return segment.copyWith(
            operationState: RouteSegmentOperationState.routing,
            clearFallbackReason: true,
          );
        })
        .toList(growable: false);
    return _accepted(
      draft,
      nowUtc,
      profile: command.profile,
      preferences: command.preferences ?? draft.preferences,
      segments: segments,
      rerouteSegmentIds: rerouteIds,
    );
  }

  RouteEditApplyResult _changeShape(
    RouteDraftData draft,
    ChangeRouteShape command,
    DateTime nowUtc,
    int maximumSegments,
  ) {
    if (draft.shape == command.shape) {
      return _reject(draft, RouteEditFailureCode.historyNoChange);
    }
    if (draft.anchors.length < 2) {
      return _accepted(draft, nowUtc, shape: command.shape);
    }
    final outward = _outwardSegments(draft);
    if (outward.isEmpty) {
      return _reject(draft, RouteEditFailureCode.shapeUnavailable);
    }
    final segments = <RouteSegmentDraft>[...outward];
    final rerouteIds = <String>[];
    String? turningAnchorId;
    if (command.shape == RouteShape.loop) {
      if (segments.length + 1 > maximumSegments) {
        return _reject(draft, RouteEditFailureCode.segmentLimitReached);
      }
      final from = draft.anchorById(segments.last.toAnchorId)!;
      final to = draft.anchorById(segments.first.fromAnchorId)!;
      final closing = _pendingSegment(
        id: _localId(),
        from: from,
        to: to,
        order: segments.length,
        draft: draft,
        nowUtc: nowUtc,
      );
      segments.add(closing);
      rerouteIds.add(closing.id);
    } else if (command.shape == RouteShape.outAndBack) {
      if (segments.length * 2 > maximumSegments) {
        return _reject(draft, RouteEditFailureCode.segmentLimitReached);
      }
      turningAnchorId = segments.last.toAnchorId;
      for (final original in outward.reversed) {
        segments.add(
          original.copyWith(
            id: _localId(),
            fromAnchorId: original.toAnchorId,
            toAnchorId: original.fromAnchorId,
            order: segments.length,
            derivation: RouteSegmentDerivation.mirrored,
            geometry: RouteGeometryDraft.fromPoints(
              original.geometry.points.reversed,
              encodingPolicy: draft.encodingPolicy,
            ),
            provenance: _derivedProvenance(original, nowUtc),
          ),
        );
      }
    }
    return _accepted(
      draft,
      nowUtc,
      shape: command.shape,
      turningAnchorId: turningAnchorId,
      clearTurningAnchorId: command.shape != RouteShape.outAndBack,
      segments: segments,
      rerouteSegmentIds: rerouteIds,
    );
  }

  RouteEditApplyResult _changeSegmentProfile(
    RouteDraftData draft,
    ChangeRouteSegmentProfile command,
    DateTime nowUtc,
  ) {
    final segment = draft.segmentById(command.segmentId);
    if (segment == null) {
      return _reject(draft, RouteEditFailureCode.segmentNotFound);
    }
    if (!command.clearOverride &&
        (command.profile == null || !command.profile!.isValid)) {
      return _reject(draft, RouteEditFailureCode.profileInvalid);
    }
    final changed = segment.copyWith(
      profileOverride: command.profile,
      clearProfileOverride: command.clearOverride,
      operationState: _isRoutable(segment)
          ? RouteSegmentOperationState.routing
          : segment.operationState,
    );
    return _accepted(
      draft,
      nowUtc,
      segments: draft.orderedSegments
          .map(
            (RouteSegmentDraft value) =>
                value.id == segment.id ? changed : value,
          )
          .toList(growable: false),
      rerouteSegmentIds: _isRoutable(segment)
          ? <String>[segment.id]
          : const <String>[],
    );
  }

  RouteEditApplyResult _setDirect(
    RouteDraftData draft,
    SetRouteSegmentDirect command,
    DateTime nowUtc,
  ) {
    final segment = draft.segmentById(command.segmentId);
    if (segment == null) {
      return _reject(draft, RouteEditFailureCode.segmentNotFound);
    }
    final from = draft.anchorById(segment.fromAnchorId)!;
    final to = draft.anchorById(segment.toAnchorId)!;
    final source = command.fallbackReason == null
        ? RouteSegmentSource.intentionalDirect
        : RouteSegmentSource.fallbackDirect;
    final direct = _newDirectSegment(
      id: segment.id,
      from: from,
      to: to,
      order: segment.order,
      source: source,
      fallbackReason: command.fallbackReason,
      draft: draft,
      nowUtc: nowUtc,
      profileOverride: segment.profileOverride,
      preferencesOverride: segment.preferencesOverride,
    );
    return _accepted(
      draft,
      nowUtc,
      segments: draft.orderedSegments
          .map(
            (RouteSegmentDraft value) =>
                value.id == segment.id ? direct : value,
          )
          .toList(growable: false),
    );
  }

  RouteEditApplyResult _reroute(
    RouteDraftData draft,
    String segmentId,
    DateTime nowUtc,
  ) {
    final segment = draft.segmentById(segmentId);
    if (segment == null) {
      return _reject(draft, RouteEditFailureCode.segmentNotFound);
    }
    final from = draft.anchorById(segment.fromAnchorId)!;
    final to = draft.anchorById(segment.toAnchorId)!;
    final pending = _pendingCopy(segment, from, to, draft, nowUtc);
    return _accepted(
      draft,
      nowUtc,
      segments: draft.orderedSegments
          .map(
            (RouteSegmentDraft value) =>
                value.id == segment.id ? pending : value,
          )
          .toList(growable: false),
      rerouteSegmentIds: <String>[segment.id],
    );
  }

  RouteEditApplyResult _addWaypoint(
    RouteDraftData draft,
    AddRouteWaypoint command,
    DateTime nowUtc,
    int maximumWaypoints,
  ) {
    if (draft.waypoints.length >= maximumWaypoints) {
      return _reject(draft, RouteEditFailureCode.waypointLimitReached);
    }
    if (command.typeId.trim().isEmpty || (command.note?.length ?? 0) > 1000) {
      return _reject(draft, RouteEditFailureCode.invalidCommand);
    }
    final anchor = draft.anchorById(command.anchorId);
    if (anchor == null) {
      return _reject(draft, RouteEditFailureCode.anchorNotFound);
    }
    final waypoint = _waypointAtAnchor(
      draft,
      id: _localId(),
      anchor: anchor,
      typeId: command.typeId.trim(),
      note: command.note?.trim(),
    );
    return _accepted(
      draft,
      nowUtc,
      waypoints: <RouteWaypointDraft>[...draft.waypoints, waypoint],
    );
  }

  RouteEditApplyResult _moveWaypoint(
    RouteDraftData draft,
    MoveRouteWaypoint command,
    DateTime nowUtc,
  ) {
    final index = draft.waypoints.indexWhere(
      (RouteWaypointDraft waypoint) => waypoint.id == command.waypointId,
    );
    if (index < 0) {
      return _reject(draft, RouteEditFailureCode.waypointNotFound);
    }
    final anchor = draft.anchorById(command.anchorId);
    if (anchor == null) {
      return _reject(draft, RouteEditFailureCode.anchorNotFound);
    }
    final current = draft.waypoints[index];
    if (current.anchorId == anchor.id) {
      return _reject(draft, RouteEditFailureCode.historyNoChange);
    }
    final moved = _waypointAtAnchor(
      draft,
      id: current.id,
      anchor: anchor,
      typeId: current.typeId,
      note: current.note,
      photoIds: current.photoIds,
      access: current.access,
    );
    final waypoints = <RouteWaypointDraft>[...draft.waypoints];
    waypoints[index] = moved;
    return _accepted(draft, nowUtc, waypoints: waypoints);
  }

  RouteEditApplyResult _removeWaypoint(
    RouteDraftData draft,
    RemoveRouteWaypoint command,
    DateTime nowUtc,
  ) {
    if (!draft.waypoints.any(
      (RouteWaypointDraft waypoint) => waypoint.id == command.waypointId,
    )) {
      return _reject(draft, RouteEditFailureCode.waypointNotFound);
    }
    return _accepted(
      draft,
      nowUtc,
      waypoints: draft.waypoints
          .where(
            (RouteWaypointDraft waypoint) => waypoint.id != command.waypointId,
          )
          .toList(growable: false),
    );
  }

  RouteEditApplyResult _changeConditions(
    RouteDraftData draft,
    ChangeRouteConditions command,
    DateTime nowUtc,
  ) => _accepted(draft.copyWith(conditions: command.conditions), nowUtc);

  RouteEditApplyResult _accepted(
    RouteDraftData draft,
    DateTime nowUtc, {
    RouteCreationMethod? creationMethod,
    RouteShape? shape,
    String? turningAnchorId,
    bool clearTurningAnchorId = false,
    RouteProfileRef? profile,
    RouteRoutingPreferences? preferences,
    Iterable<RouteAnchorDraft>? anchors,
    Iterable<RouteSegmentDraft>? segments,
    Iterable<RouteWaypointDraft>? waypoints,
    Iterable<RouteSourceIssueDraft>? sourceIssues,
    Iterable<String> rerouteSegmentIds = const <String>[],
  }) {
    final nextGeometryRevision = draft.geometryRevision + 1;
    final nextSegments = (segments ?? draft.segments)
        .map(
          (RouteSegmentDraft segment) =>
              segment.copyWith(geometryRevision: nextGeometryRevision),
        )
        .toList(growable: false);
    final nextMetrics = _metricsFor(
      draft.metrics,
      nextSegments,
      nextGeometryRevision,
      draft.conditions,
    );
    return RouteEditApplyResult.accepted(
      draft: draft.copyWith(
        revision: draft.revision + 1,
        geometryRevision: nextGeometryRevision,
        creationMethod: creationMethod,
        shape: shape,
        turningAnchorId: turningAnchorId,
        clearTurningAnchorId: clearTurningAnchorId,
        profile: profile,
        preferences: preferences,
        anchors: anchors,
        segments: nextSegments,
        waypoints: waypoints,
        sourceIssues: sourceIssues,
        metrics: nextMetrics,
        operations: const <RouteAsyncOperationDraft>[],
      ),
      rerouteSegmentIds: rerouteSegmentIds,
    );
  }

  RouteWaypointDraft _waypointAtAnchor(
    RouteDraftData draft, {
    required String id,
    required RouteAnchorDraft anchor,
    required String typeId,
    String? note,
    Iterable<String> photoIds = const <String>[],
    RouteAccessInfoDraft? access,
  }) {
    var distance = 0.0;
    if (draft.orderedSegments.isNotEmpty &&
        draft.orderedSegments.first.fromAnchorId != anchor.id) {
      for (final segment in draft.orderedSegments) {
        distance += segment.distanceMeters;
        if (segment.toAnchorId == anchor.id) break;
      }
    }
    return RouteWaypointDraft(
      id: id,
      anchorId: anchor.id,
      position: anchor.position,
      typeId: typeId,
      trackState: RouteWaypointTrackState.onTrack,
      distanceFromStartMeters: distance,
      distanceFromTrackMeters: 0,
      note: note == null || note.isEmpty ? null : note,
      photoIds: photoIds.toList(growable: false),
      access: access,
    );
  }

  RouteSegmentDraft _replacementSegment({
    required RouteSegmentDraft template,
    required String id,
    required RouteAnchorDraft from,
    required RouteAnchorDraft to,
    required int order,
    required RouteDraftData draft,
    required DateTime nowUtc,
    RouteSegmentDerivation? derivation,
  }) {
    if (_isDirect(template)) {
      return _newDirectSegment(
        id: id,
        from: from,
        to: to,
        order: order,
        source: template.source,
        fallbackReason: template.fallbackReason,
        draft: draft,
        nowUtc: nowUtc,
        derivation: derivation ?? template.derivation,
        profileOverride: template.profileOverride,
        preferencesOverride: template.preferencesOverride,
      );
    }
    return _pendingSegment(
      id: id,
      from: from,
      to: to,
      order: order,
      draft: draft,
      nowUtc: nowUtc,
    ).copyWith(
      derivation: derivation ?? template.derivation,
      profileOverride: template.profileOverride,
      preferencesOverride: template.preferencesOverride,
    );
  }

  RouteSegmentDraft _replacementFromPair({
    required RouteSegmentDraft incoming,
    required RouteSegmentDraft outgoing,
    required RouteAnchorDraft from,
    required RouteAnchorDraft to,
    required int order,
    required RouteDraftData draft,
    required DateTime nowUtc,
    RouteSegmentDerivation? derivation,
  }) => _replacementSegment(
    template: incoming,
    id: _localId(),
    from: from,
    to: to,
    order: order,
    draft: draft,
    nowUtc: nowUtc,
    derivation: derivation,
  );

  RouteSegmentDraft _pendingSegment({
    required String id,
    required RouteAnchorDraft from,
    required RouteAnchorDraft to,
    required int order,
    required RouteDraftData draft,
    required DateTime nowUtc,
  }) => RouteSegmentDraft(
    id: id,
    fromAnchorId: from.id,
    toAnchorId: to.id,
    order: order,
    source: RouteSegmentSource.routed,
    derivation: RouteSegmentDerivation.original,
    geometry: RouteGeometryDraft.fromPoints(<GeoPoint>[
      from.position,
      to.position,
    ], encodingPolicy: draft.encodingPolicy),
    provenance: RouteProvenanceDraft(
      sourceId: 'pending-routing',
      sourceRevision: draft.revision + 1,
      createdAtUtc: nowUtc,
      algorithmVersion: 'pending-v1',
    ),
    geometryRevision: draft.geometryRevision + 1,
    operationState: RouteSegmentOperationState.routing,
  );

  RouteSegmentDraft _pendingCopy(
    RouteSegmentDraft segment,
    RouteAnchorDraft from,
    RouteAnchorDraft to,
    RouteDraftData draft,
    DateTime nowUtc,
  ) =>
      _pendingSegment(
        id: segment.id,
        from: from,
        to: to,
        order: segment.order,
        draft: draft,
        nowUtc: nowUtc,
      ).copyWith(
        profileOverride: segment.profileOverride,
        preferencesOverride: segment.preferencesOverride,
      );

  RouteSegmentDraft _directCopy(
    RouteSegmentDraft segment,
    RouteAnchorDraft from,
    RouteAnchorDraft to,
    RouteDraftData draft,
    DateTime nowUtc,
  ) => _newDirectSegment(
    id: segment.id,
    from: from,
    to: to,
    order: segment.order,
    source: segment.source,
    fallbackReason: segment.fallbackReason,
    draft: draft,
    nowUtc: nowUtc,
    profileOverride: segment.profileOverride,
    preferencesOverride: segment.preferencesOverride,
  );

  RouteSegmentDraft _newDirectSegment({
    required String id,
    required RouteAnchorDraft from,
    required RouteAnchorDraft to,
    required int order,
    required RouteSegmentSource source,
    required RouteRoutingFailureCode? fallbackReason,
    required RouteDraftData draft,
    required DateTime nowUtc,
    RouteSegmentDerivation derivation = RouteSegmentDerivation.original,
    RouteProfileRef? profileOverride,
    RouteRoutingPreferences? preferencesOverride,
  }) => RouteSegmentDraft(
    id: id,
    fromAnchorId: from.id,
    toAnchorId: to.id,
    order: order,
    source: source,
    derivation: derivation,
    geometry: RouteGeometryDraft.fromPoints(<GeoPoint>[
      from.position,
      to.position,
    ], encodingPolicy: draft.encodingPolicy),
    provenance: RouteProvenanceDraft(
      sourceId: 'author-direct',
      sourceRevision: draft.revision + 1,
      createdAtUtc: nowUtc,
      algorithmVersion: 'direct-v1',
    ),
    geometryRevision: draft.geometryRevision + 1,
    profileOverride: profileOverride,
    preferencesOverride: preferencesOverride,
    needsReview: source == RouteSegmentSource.fallbackDirect,
    fallbackReason: fallbackReason,
  );

  static RouteProvenanceDraft _derivedProvenance(
    RouteSegmentDraft parent,
    DateTime nowUtc,
  ) => RouteProvenanceDraft(
    sourceId: parent.provenance.sourceId,
    sourceRevision: parent.provenance.sourceRevision + 1,
    createdAtUtc: nowUtc,
    parentSegmentId: parent.id,
    algorithmVersion: parent.provenance.algorithmVersion,
    provider: parent.provenance.provider,
  );

  static RouteMetricsDraft _metricsFor(
    RouteMetricsDraft previous,
    List<RouteSegmentDraft> segments,
    int geometryRevision,
    RouteConditionsDraft conditions,
  ) {
    final distance = segments.fold<double>(
      0,
      (double total, RouteSegmentDraft segment) =>
          total + segment.distanceMeters,
    );
    final secondsPerMeter = previous.distanceMeters > 0
        ? previous.autoDurationSeconds / previous.distanceMeters
        : 0.714285714;
    final autoDuration = (distance * secondsPerMeter).round();
    final directDistance = segments
        .where(
          (RouteSegmentDraft segment) =>
              segment.source == RouteSegmentSource.intentionalDirect,
        )
        .fold<double>(
          0,
          (double total, RouteSegmentDraft segment) =>
              total + segment.distanceMeters,
        );
    final fallbackDistance = segments
        .where(
          (RouteSegmentDraft segment) =>
              segment.source == RouteSegmentSource.fallbackDirect,
        )
        .fold<double>(
          0,
          (double total, RouteSegmentDraft segment) =>
              total + segment.distanceMeters,
        );
    return RouteMetricsDraft(
      geometryRevision: geometryRevision,
      calculationModelId: previous.calculationModelId,
      calculationModelVersion: previous.calculationModelVersion,
      distanceMeters: distance,
      autoDurationSeconds: autoDuration,
      effectiveDurationSeconds:
          conditions.manualDuration?.seconds ?? autoDuration,
      directDistanceMeters: directDistance,
      fallbackDistanceMeters: fallbackDistance,
      surfaceDistanceMeters: <String, double>{
        if (distance > 0) 'mixed': distance,
      },
      difficultyId: previous.difficultyId,
    );
  }

  static List<RouteSegmentDraft> _outwardSegments(RouteDraftData draft) {
    final ordered = draft.orderedSegments;
    if (draft.shape == RouteShape.oneWay) return ordered;
    if (draft.shape == RouteShape.loop) {
      if (ordered.isEmpty) return ordered;
      return ordered.sublist(0, ordered.length - 1);
    }
    final turning = draft.turningAnchorId;
    if (turning == null) return const <RouteSegmentDraft>[];
    final result = <RouteSegmentDraft>[];
    for (final segment in ordered) {
      result.add(segment);
      if (segment.toAnchorId == turning) break;
    }
    return result;
  }

  static int? _nearestInteriorPointIndex(
    List<GeoPoint> points,
    GeoPoint target,
  ) {
    if (points.length < 3) return null;
    var bestIndex = 1;
    var bestDistance = double.infinity;
    for (var index = 1; index < points.length - 1; index += 1) {
      final distance = GeoDistance.haversineMeters(points[index], target);
      if (distance < bestDistance) {
        bestIndex = index;
        bestDistance = distance;
      }
    }
    return bestIndex;
  }

  static bool _compatibleForMerge(
    RouteSegmentDraft first,
    RouteSegmentDraft second,
  ) =>
      first.source == second.source &&
      first.derivation == second.derivation &&
      first.profileOverride?.id == second.profileOverride?.id &&
      first.profileOverride?.version == second.profileOverride?.version &&
      _samePreferences(first.preferencesOverride, second.preferencesOverride);

  static bool _canJoinAutomatically(
    RouteSegmentDraft incoming,
    RouteSegmentDraft outgoing,
  ) {
    final sameProfile =
        incoming.profileOverride?.id == outgoing.profileOverride?.id &&
        incoming.profileOverride?.version ==
            outgoing.profileOverride?.version &&
        _samePreferences(
          incoming.preferencesOverride,
          outgoing.preferencesOverride,
        );
    if (!sameProfile) return false;
    if (_isDirect(incoming) && _isDirect(outgoing)) {
      return incoming.source == outgoing.source;
    }
    return _isRoutable(incoming) && _isRoutable(outgoing);
  }

  static bool _samePreferences(
    RouteRoutingPreferences? left,
    RouteRoutingPreferences? right,
  ) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    if (left.schemaVersion != right.schemaVersion ||
        left.values.length != right.values.length) {
      return false;
    }
    for (final entry in left.values.entries) {
      final other = right.values[entry.key];
      if (other == null ||
          other.runtimeType != entry.value.runtimeType ||
          other.value != entry.value.value) {
        return false;
      }
    }
    return true;
  }

  static bool _isRoutable(RouteSegmentDraft segment) =>
      segment.source == RouteSegmentSource.routed ||
      segment.source == RouteSegmentSource.generated;

  static bool _isDirect(RouteSegmentDraft segment) =>
      segment.source == RouteSegmentSource.intentionalDirect ||
      segment.source == RouteSegmentSource.fallbackDirect;

  static bool _canReshape(RouteSegmentDraft segment) =>
      _isRoutable(segment) || _isDirect(segment);

  static RouteWaypointDraft _unresolveWaypoint(RouteWaypointDraft waypoint) =>
      RouteWaypointDraft(
        id: waypoint.id,
        position: waypoint.position,
        typeId: waypoint.typeId,
        trackState: RouteWaypointTrackState.unresolved,
        distanceFromTrackMeters: waypoint.distanceFromTrackMeters,
        catalogVersion: waypoint.catalogVersion,
        title: waypoint.title,
        description: waypoint.description,
        note: waypoint.note,
        safetyNote: waypoint.safetyNote,
        technicalAttributeIds: waypoint.technicalAttributeIds,
        photoIds: waypoint.photoIds,
        verifiedAtUtc: waypoint.verifiedAtUtc,
        access: waypoint.access,
      );

  static List<RouteWaypointDraft> _unresolveWaypointsFor(
    RouteDraftData draft, {
    required String? removedAnchorId,
    required Set<String> removedSegmentIds,
  }) => draft.waypoints
      .map((RouteWaypointDraft waypoint) {
        if ((removedAnchorId != null && waypoint.anchorId == removedAnchorId) ||
            (waypoint.segmentId != null &&
                removedSegmentIds.contains(waypoint.segmentId))) {
          return _unresolveWaypoint(waypoint);
        }
        return waypoint;
      })
      .toList(growable: false);

  static List<RouteAnchorDraft> _insertAnchorAfter(
    List<RouteAnchorDraft> anchors, {
    required String afterAnchorId,
    required RouteAnchorDraft anchor,
  }) {
    final result = <RouteAnchorDraft>[...anchors];
    final index = result.indexWhere(
      (RouteAnchorDraft value) => value.id == afterAnchorId,
    );
    result.insert(index < 0 ? result.length : index + 1, anchor);
    return result;
  }

  static RouteWaypointDraft _copyWaypoint(
    RouteWaypointDraft waypoint, {
    String? segmentId,
    double? distanceFromStartMeters,
  }) => RouteWaypointDraft(
    id: waypoint.id,
    anchorId: waypoint.anchorId,
    segmentId: segmentId ?? waypoint.segmentId,
    position: waypoint.position,
    typeId: waypoint.typeId,
    trackState: waypoint.trackState,
    distanceFromStartMeters:
        distanceFromStartMeters ?? waypoint.distanceFromStartMeters,
    distanceFromTrackMeters: waypoint.distanceFromTrackMeters,
    catalogVersion: waypoint.catalogVersion,
    title: waypoint.title,
    description: waypoint.description,
    note: waypoint.note,
    safetyNote: waypoint.safetyNote,
    technicalAttributeIds: waypoint.technicalAttributeIds,
    photoIds: waypoint.photoIds,
    verifiedAtUtc: waypoint.verifiedAtUtc,
    access: waypoint.access,
  );

  RouteEditApplyResult _reject(
    RouteDraftData draft,
    RouteEditFailureCode code,
  ) => RouteEditApplyResult.rejected(draft: draft, failureCode: code);

  String _localId() => 'loc_${_idGenerator.generate()}';
}

class RouteRoutingResultData {
  const RouteRoutingResultData({
    required this.operationId,
    required this.segmentId,
    required this.geometry,
    required this.provenance,
    this.providerDurationSeconds,
  });

  final String operationId;
  final String segmentId;
  final RouteGeometryDraft geometry;
  final RouteProvenanceDraft provenance;
  final int? providerDurationSeconds;
}
