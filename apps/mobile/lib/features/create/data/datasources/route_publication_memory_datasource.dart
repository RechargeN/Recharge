import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/route_publication_data.dart';

enum RoutePublicationFaultPoint {
  beforeSubmitCommit,
  beforePublishCommit,
  beforeDecisionCommit,
  beforeArchiveCommit,
  beforeLifecycleCommit,
}

class RoutePublicationInjectedFault implements Exception {
  const RoutePublicationInjectedFault(this.point);

  final RoutePublicationFaultPoint point;
}

class RoutePublicationMemoryDataSource {
  RoutePublicationMemoryDataSource({
    bool Function(RoutePublicationFaultPoint point)? shouldFail,
  }) : _shouldFail = shouldFail ?? ((_) => false);

  final bool Function(RoutePublicationFaultPoint point) _shouldFail;
  final Map<String, RoutePublicationAggregate> _routes =
      <String, RoutePublicationAggregate>{};
  final Map<String, RouteModerationRequest> _requests =
      <String, RouteModerationRequest>{};
  final Map<String, RoutePublishReceipt> _attemptReceipts =
      <String, RoutePublishReceipt>{};

  RoutePublishReceipt submit({
    required String requestId,
    required RoutePublicationBundle bundle,
  }) {
    final repeated = _attemptReceipts[bundle.attemptId];
    if (repeated != null) return repeated;
    RouteModerationRequest? existingRequest;
    for (final request in _requests.values) {
      if (request.state == RouteModerationState.pending &&
          request.bundle.version.routeId == bundle.version.routeId &&
          request.bundle.version.contentHash == bundle.version.contentHash &&
          request.bundle.version.rollbackSourceVersionId ==
              bundle.version.rollbackSourceVersionId) {
        existingRequest = request;
        break;
      }
    }
    if (existingRequest != null) {
      final receipt = _submittedReceipt(existingRequest);
      _attemptReceipts[bundle.attemptId] = receipt;
      return receipt;
    }

    final active = _routes[bundle.version.routeId]?.activeVersion;
    if (active != null &&
        active.contentHash == bundle.version.contentHash &&
        bundle.version.rollbackSourceVersionId == null) {
      final receipt = _publishedReceipt(
        active,
        RoutePublishReceiptStatus.idempotent,
      );
      _attemptReceipts[bundle.attemptId] = receipt;
      return receipt;
    }

    final request = RouteModerationRequest(
      id: requestId,
      attemptId: bundle.attemptId,
      bundle: bundle,
      state: RouteModerationState.pending,
      submittedAtUtc: bundle.auditEvent.occurredAtUtc,
    );
    _failIfRequested(RoutePublicationFaultPoint.beforeSubmitCommit);
    _requests[requestId] = request;
    final receipt = _submittedReceipt(request);
    _attemptReceipts[bundle.attemptId] = receipt;
    return receipt;
  }

  RoutePublishReceipt publishDirect(RoutePublicationBundle bundle) {
    final repeated = _attemptReceipts[bundle.attemptId];
    if (repeated != null) return repeated;
    final conflict = _hasVersionConflict(bundle.version);
    if (conflict) {
      return _conflictReceipt(bundle);
    }
    final current = _routes[bundle.version.routeId];
    final active = current?.activeVersion;
    if (active != null &&
        active.contentHash == bundle.version.contentHash &&
        bundle.version.rollbackSourceVersionId == null) {
      final receipt = _publishedReceipt(
        active,
        RoutePublishReceiptStatus.idempotent,
      );
      _attemptReceipts[bundle.attemptId] = receipt;
      return receipt;
    }

    final next = _aggregateWithPublishedVersion(current, bundle);
    _failIfRequested(RoutePublicationFaultPoint.beforePublishCommit);
    _routes[next.routeId] = next;
    final receipt = _publishedReceipt(
      bundle.version,
      RoutePublishReceiptStatus.published,
    );
    _attemptReceipts[bundle.attemptId] = receipt;
    return receipt;
  }

  RoutePublishReceipt decide(RouteModerationDecision decision) {
    final repeated = _attemptReceipts[decision.attemptId];
    if (repeated != null) return repeated;
    final request = _requests[decision.requestId];
    if (request == null) {
      return _decisionFailure(
        decision,
        reasonCode: 'moderation_request_not_found',
      );
    }
    if (request.state != RouteModerationState.pending) {
      final version = request.bundle.version;
      final status = request.state == RouteModerationState.approved
          ? RoutePublishReceiptStatus.idempotent
          : RoutePublishReceiptStatus.denied;
      final receipt = RoutePublishReceipt(
        status: status,
        routeId: version.routeId,
        versionId: version.versionId,
        geometryHash: version.geometryHash,
        displayDraft: _displayDraft(
          version,
          published: request.state == RouteModerationState.approved,
        ),
        requestId: request.id,
        reasonCode: request.reasonCode,
      );
      _attemptReceipts[decision.attemptId] = receipt;
      return receipt;
    }

    final version = request.bundle.version;
    if (!decision.approved) {
      final reason = decision.reasonCode?.trim();
      if (reason == null || reason.isEmpty) {
        return _decisionFailure(
          decision,
          request: request,
          reasonCode: 'rejection_reason_required',
        );
      }
      final rejected = request.copyWith(
        state: RouteModerationState.rejected,
        decidedAtUtc: decision.decidedAtUtc,
        decidedBy: decision.actorId,
        reasonCode: reason,
      );
      _failIfRequested(RoutePublicationFaultPoint.beforeDecisionCommit);
      _requests[request.id] = rejected;
      final receipt = RoutePublishReceipt(
        status: RoutePublishReceiptStatus.denied,
        routeId: version.routeId,
        versionId: version.versionId,
        geometryHash: version.geometryHash,
        displayDraft: _displayDraft(version, published: false),
        requestId: request.id,
        reasonCode: reason,
      );
      _attemptReceipts[decision.attemptId] = receipt;
      return receipt;
    }

    if (_hasVersionConflict(version)) {
      return _decisionFailure(
        decision,
        request: request,
        reasonCode: 'active_version_changed',
      );
    }
    final current = _routes[version.routeId];
    final approvalAudit = RoutePublicationAuditEvent(
      id: 'audit:${decision.attemptId}',
      action: 'route_moderation_approved',
      actorId: decision.actorId,
      publisher: version.publisher,
      routeId: version.routeId,
      versionId: version.versionId,
      attemptId: decision.attemptId,
      occurredAtUtc: decision.decidedAtUtc,
    );
    final next = RoutePublicationAggregate(
      routeId: version.routeId,
      versions: <PublishedRouteVersion>[...?current?.versions, version],
      activeVersionId: version.versionId,
      lifecycleStatus: RouteLifecycleStatus.active,
      auditTrail: <RoutePublicationAuditEvent>[
        ...?current?.auditTrail,
        request.bundle.auditEvent,
        approvalAudit,
      ],
    );
    final approved = request.copyWith(
      state: RouteModerationState.approved,
      decidedAtUtc: decision.decidedAtUtc,
      decidedBy: decision.actorId,
    );
    _failIfRequested(RoutePublicationFaultPoint.beforeDecisionCommit);
    _routes[next.routeId] = next;
    _requests[request.id] = approved;
    final receipt = _publishedReceipt(
      version,
      RoutePublishReceiptStatus.published,
      requestId: request.id,
    );
    _attemptReceipts[decision.attemptId] = receipt;
    return receipt;
  }

  List<RouteModerationRequest> pendingRequests() {
    final values =
        _requests.values
            .where((request) => request.state == RouteModerationState.pending)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.submittedAtUtc.compareTo(right.submittedAtUtc),
          );
    return List<RouteModerationRequest>.unmodifiable(values);
  }

  RouteModerationRequest? requestById(String requestId) => _requests[requestId];

  RoutePublicationAggregate? routeById(String routeId) => _routes[routeId];

  RoutePublicationAggregate? routeByVersionId(String versionId) {
    for (final route in _routes.values) {
      if (route.versions.any((version) => version.versionId == versionId)) {
        return route;
      }
    }
    return null;
  }

  RoutePublicationAggregate? archive({
    required String routeId,
    required String actorId,
    required String attemptId,
    required DateTime archivedAtUtc,
  }) {
    final current = _routes[routeId];
    final active = current?.activeVersion;
    if (current == null || active == null) return null;
    if (current.lifecycleStatus == RouteLifecycleStatus.archived) {
      return current;
    }
    final audit = RoutePublicationAuditEvent(
      id: 'audit:$attemptId',
      action: 'route_archived',
      actorId: actorId,
      publisher: active.publisher,
      routeId: routeId,
      versionId: active.versionId,
      attemptId: attemptId,
      occurredAtUtc: archivedAtUtc,
    );
    final archived = RoutePublicationAggregate(
      routeId: routeId,
      versions: current.versions,
      activeVersionId: current.activeVersionId,
      lifecycleStatus: RouteLifecycleStatus.archived,
      auditTrail: <RoutePublicationAuditEvent>[...current.auditTrail, audit],
    );
    _failIfRequested(RoutePublicationFaultPoint.beforeArchiveCommit);
    _routes[routeId] = archived;
    return archived;
  }

  RoutePublicationAggregate? setLifecycle({
    required String routeId,
    required RouteLifecycleStatus status,
    required String actorId,
    required String attemptId,
    required String reasonCode,
    required DateTime changedAtUtc,
  }) {
    final current = _routes[routeId];
    final active = current?.activeVersion;
    if (current == null || active == null) return null;
    if (status == RouteLifecycleStatus.archived) {
      throw ArgumentError.value(status, 'status', 'Use archive().');
    }
    if (reasonCode.trim().isEmpty || !changedAtUtc.isUtc) {
      throw ArgumentError('A reason code and UTC timestamp are required.');
    }
    if (current.lifecycleStatus == status) return current;
    final action = switch (status) {
      RouteLifecycleStatus.active => 'route_safety_restored',
      RouteLifecycleStatus.needsReview => 'route_safety_needs_review',
      RouteLifecycleStatus.suspended => 'route_safety_suspended',
      RouteLifecycleStatus.archived => throw StateError('Unreachable status.'),
    };
    final audit = RoutePublicationAuditEvent(
      id: 'audit:$attemptId',
      action: action,
      actorId: actorId,
      publisher: active.publisher,
      routeId: routeId,
      versionId: active.versionId,
      attemptId: attemptId,
      occurredAtUtc: changedAtUtc,
      reasonCode: reasonCode,
    );
    final next = RoutePublicationAggregate(
      routeId: routeId,
      versions: current.versions,
      activeVersionId: current.activeVersionId,
      lifecycleStatus: status,
      auditTrail: <RoutePublicationAuditEvent>[...current.auditTrail, audit],
    );
    _failIfRequested(RoutePublicationFaultPoint.beforeLifecycleCommit);
    _routes[routeId] = next;
    return next;
  }

  bool _hasVersionConflict(PublishedRouteVersion candidate) {
    final activeVersionId = _routes[candidate.routeId]?.activeVersionId;
    return activeVersionId != candidate.previousVersionId;
  }

  static RoutePublicationAggregate _aggregateWithPublishedVersion(
    RoutePublicationAggregate? current,
    RoutePublicationBundle bundle,
  ) => RoutePublicationAggregate(
    routeId: bundle.version.routeId,
    versions: <PublishedRouteVersion>[...?current?.versions, bundle.version],
    activeVersionId: bundle.version.versionId,
    lifecycleStatus: RouteLifecycleStatus.active,
    auditTrail: <RoutePublicationAuditEvent>[
      ...?current?.auditTrail,
      bundle.auditEvent,
    ],
  );

  static RoutePublishReceipt _submittedReceipt(RouteModerationRequest request) {
    final version = request.bundle.version;
    return RoutePublishReceipt(
      status: RoutePublishReceiptStatus.submitted,
      routeId: version.routeId,
      versionId: version.versionId,
      geometryHash: version.geometryHash,
      displayDraft: _displayDraft(version, published: false),
      requestId: request.id,
    );
  }

  static RoutePublishReceipt _publishedReceipt(
    PublishedRouteVersion version,
    RoutePublishReceiptStatus status, {
    String? requestId,
  }) => RoutePublishReceipt(
    status: status,
    routeId: version.routeId,
    versionId: version.versionId,
    geometryHash: version.geometryHash,
    displayDraft: _displayDraft(version, published: true),
    requestId: requestId,
  );

  static RoutePublishReceipt _conflictReceipt(RoutePublicationBundle bundle) =>
      RoutePublishReceipt(
        status: RoutePublishReceiptStatus.conflict,
        routeId: bundle.version.routeId,
        versionId: bundle.version.versionId,
        geometryHash: bundle.version.geometryHash,
        displayDraft: _displayDraft(bundle.version, published: false),
        reasonCode: 'active_version_changed',
      );

  static RoutePublishReceipt _decisionFailure(
    RouteModerationDecision decision, {
    RouteModerationRequest? request,
    required String reasonCode,
  }) {
    final version = request?.bundle.version;
    return RoutePublishReceipt(
      status: RoutePublishReceiptStatus.invalid,
      routeId: version?.routeId ?? '',
      versionId: version?.versionId ?? '',
      geometryHash: version?.geometryHash ?? '',
      displayDraft:
          version?.contentSnapshot ??
          CreateDraftEntity.defaults(
            organizerId: decision.actorId,
            organizerEmail: '',
            organizerName: '',
          ),
      requestId: request?.id ?? decision.requestId,
      reasonCode: reasonCode,
    );
  }

  static CreateDraftEntity _displayDraft(
    PublishedRouteVersion version, {
    required bool published,
  }) => version.contentSnapshot.copyWith(
    draftStatus: published ? DraftStatus.published : DraftStatus.pendingReview,
    moderationStatus: published
        ? ModerationStatus.approved
        : ModerationStatus.pending,
    publishStatus: published
        ? PublishStatus.published
        : PublishStatus.pendingReview,
    clearPublishedAtUtc: !published,
  );

  void _failIfRequested(RoutePublicationFaultPoint point) {
    if (_shouldFail(point)) throw RoutePublicationInjectedFault(point);
  }
}
