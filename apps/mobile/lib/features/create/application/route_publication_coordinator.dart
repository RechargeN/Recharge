import '../../../core/id/id_generator.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/route_publication_data.dart';
import '../domain/repositories/route_authoring_policy.dart';
import '../domain/repositories/route_publication_repository.dart';
import '../domain/usecases/build_route_publication_bundle_usecase.dart';

class RoutePublicationAuthorizationException implements Exception {
  const RoutePublicationAuthorizationException(this.reasonCode);

  final String reasonCode;
}

class RoutePublicationCoordinator {
  RoutePublicationCoordinator({
    required IdGenerator idGenerator,
    required RoutePublicationRepository repository,
    required RouteAuthoringPolicy authoringPolicy,
    required BuildRoutePublicationBundleUseCase buildBundle,
    required RoutePublicationBuildPolicy buildPolicy,
    DateTime Function()? clock,
  }) : _idGenerator = idGenerator,
       _repository = repository,
       _authoringPolicy = authoringPolicy,
       _buildBundle = buildBundle,
       _buildPolicy = buildPolicy,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final IdGenerator _idGenerator;
  final RoutePublicationRepository _repository;
  final RouteAuthoringPolicy _authoringPolicy;
  final BuildRoutePublicationBundleUseCase _buildBundle;
  final RoutePublicationBuildPolicy _buildPolicy;
  final DateTime Function() _clock;

  Future<RoutePublishReceipt> publish({
    required String actorId,
    required Set<String> capabilities,
    required CreateDraftEntity draft,
    RoutePublisherType publisherType = RoutePublisherType.user,
    String? publisherId,
    String? attemptId,
  }) async {
    final direct = capabilities.contains('publish.route.direct');
    final publisher = RoutePublisherRef(
      type: publisherType,
      id: publisherId ?? actorId,
    );
    await _requireAllowed(
      actorId: actorId,
      draftId: draft.id,
      capabilities: capabilities,
      operation: direct
          ? RouteAuthoringOperation.publishDirect
          : RouteAuthoringOperation.submitForReview,
      publisher: publisher,
    );

    final current = await _currentFor(draft);
    final routeId = current?.routeId ?? _idGenerator.generate();
    final effectiveAttemptId = attemptId ?? _idGenerator.generate();
    final bundle = _buildBundle(
      draft: draft,
      current: current,
      publisher: publisher,
      mode: direct
          ? RoutePublicationMode.trustedDirect
          : RoutePublicationMode.reviewed,
      policy: _buildPolicy,
      routeId: routeId,
      versionId: _idGenerator.generate(),
      auditEventId: _idGenerator.generate(),
      attemptId: effectiveAttemptId,
      actorId: actorId,
      nowUtc: _clock().toUtc(),
      generateId: _idGenerator.generate,
    );
    if (direct) return _repository.publishDirect(bundle);
    return _repository.submitForReview(
      requestId: _idGenerator.generate(),
      bundle: bundle,
    );
  }

  Future<List<RouteModerationRequest>> pendingRequests({
    required String actorId,
    required Set<String> capabilities,
  }) async {
    await _requireAllowed(
      actorId: actorId,
      draftId: 'route-moderation-queue',
      capabilities: capabilities,
      operation: RouteAuthoringOperation.moderate,
    );
    return _repository.pendingRequests();
  }

  Future<RoutePublishReceipt> moderate({
    required String actorId,
    required Set<String> capabilities,
    required String requestId,
    required bool approved,
    String? reasonCode,
    String? attemptId,
  }) async {
    await _requireAllowed(
      actorId: actorId,
      draftId: requestId,
      capabilities: capabilities,
      operation: RouteAuthoringOperation.moderate,
    );
    return _repository.decide(
      RouteModerationDecision(
        requestId: requestId,
        approved: approved,
        actorId: actorId,
        attemptId: attemptId ?? _idGenerator.generate(),
        decidedAtUtc: _clock().toUtc(),
        reasonCode: reasonCode,
      ),
    );
  }

  Future<CreateDraftEntity> createRevision({
    required String actorId,
    required Set<String> capabilities,
    required String versionId,
  }) async {
    final aggregate = await _repository.routeByVersionId(versionId);
    final version = _versionById(aggregate, versionId);
    if (aggregate == null || version == null) {
      throw const RoutePublicationAuthorizationException(
        'published_route_version_not_found',
      );
    }
    await _requireAllowed(
      actorId: actorId,
      draftId: aggregate.routeId,
      capabilities: capabilities,
      operation: RouteAuthoringOperation.createRevision,
      publisher: version.publisher,
    );
    return version.contentSnapshot.copyWith(
      id: 'loc_${_idGenerator.generate()}',
      basedOnPublishedVersionId: version.versionId,
      routeData: version.contentSnapshot.routeData?.nextRevision(),
      draftStatus: DraftStatus.draft,
      moderationStatus: ModerationStatus.none,
      publishStatus: PublishStatus.draft,
      updatedAtUtc: _clock().toUtc(),
      clearPublishedAtUtc: true,
    );
  }

  Future<RoutePublicationAggregate?> archive({
    required String actorId,
    required Set<String> capabilities,
    required String routeId,
    String? attemptId,
  }) async {
    await _requireAllowed(
      actorId: actorId,
      draftId: routeId,
      capabilities: capabilities,
      operation: RouteAuthoringOperation.archive,
    );
    return _repository.archive(
      routeId: routeId,
      actorId: actorId,
      attemptId: attemptId ?? _idGenerator.generate(),
      archivedAtUtc: _clock().toUtc(),
    );
  }

  Future<RoutePublishReceipt> rollback({
    required String actorId,
    required Set<String> capabilities,
    required String routeId,
    required String targetVersionId,
    String? attemptId,
  }) async {
    final aggregate = await _repository.routeById(routeId);
    final target = _versionById(aggregate, targetVersionId);
    final active = aggregate?.activeVersion;
    if (aggregate == null || target == null || active == null) {
      throw const RoutePublicationAuthorizationException(
        'published_route_version_not_found',
      );
    }
    if (target.versionId == active.versionId) {
      throw const RoutePublicationAuthorizationException(
        'rollback_target_is_active',
      );
    }
    await _requireAllowed(
      actorId: actorId,
      draftId: routeId,
      capabilities: capabilities,
      operation: RouteAuthoringOperation.rollbackRoute,
      publisher: active.publisher,
    );
    final direct = capabilities.contains('publish.route.direct');
    await _requireAllowed(
      actorId: actorId,
      draftId: routeId,
      capabilities: capabilities,
      operation: direct
          ? RouteAuthoringOperation.publishDirect
          : RouteAuthoringOperation.submitForReview,
      publisher: active.publisher,
    );
    final now = _clock().toUtc();
    final versionId = _idGenerator.generate();
    final effectiveAttemptId = attemptId ?? _idGenerator.generate();
    final geometry = PublishedRouteGeometry(
      routeId: routeId,
      versionId: versionId,
      geometryHash: target.geometryHash,
      fullEncodedPolyline: target.geometry.fullEncodedPolyline,
      segments: target.geometry.segments,
      waypoints: target.geometry.waypoints,
      providers: target.geometry.providers,
      encodingPolicyId: target.geometry.encodingPolicyId,
      encodingPolicyVersion: target.geometry.encodingPolicyVersion,
      quality: target.geometry.quality,
    );
    final sourceProjection = target.projection;
    final projection = RouteSearchProjection(
      routeId: routeId,
      versionId: versionId,
      geometryHash: target.geometryHash,
      marketId: sourceProjection.marketId,
      startPoint: sourceProjection.startPoint,
      bounds: sourceProjection.bounds,
      overviewEncodedPolyline: sourceProjection.overviewEncodedPolyline,
      distanceMeters: sourceProjection.distanceMeters,
      effectiveDurationSeconds: sourceProjection.effectiveDurationSeconds,
      routingProfileId: sourceProjection.routingProfileId,
      difficultyId: sourceProjection.difficultyId,
      categoryIds: sourceProjection.categoryIds,
      searchTokens: sourceProjection.searchTokens,
    );
    final content = target.contentSnapshot.copyWith(
      id: routeId,
      basedOnPublishedVersionId: active.versionId,
      draftStatus: DraftStatus.published,
      moderationStatus: ModerationStatus.approved,
      publishStatus: PublishStatus.published,
      updatedAtUtc: now,
      publishedAtUtc: now,
    );
    final mode = direct
        ? RoutePublicationMode.trustedDirect
        : RoutePublicationMode.reviewed;
    final version = PublishedRouteVersion(
      routeId: routeId,
      versionId: versionId,
      versionNumber: active.versionNumber + 1,
      previousVersionId: active.versionId,
      publisher: active.publisher,
      authorId: actorId,
      contentHash: target.contentHash,
      geometryHash: target.geometryHash,
      mode: mode,
      demoOnly: target.demoOnly,
      contentSnapshot: content,
      geometry: geometry,
      projection: projection,
      createdAtUtc: now,
      publishedAtUtc: now,
      rollbackSourceVersionId: target.versionId,
    );
    final bundle = RoutePublicationBundle(
      attemptId: effectiveAttemptId,
      version: version,
      auditEvent: RoutePublicationAuditEvent(
        id: _idGenerator.generate(),
        action: direct
            ? 'route_rollback_published'
            : 'route_rollback_submitted',
        actorId: actorId,
        publisher: active.publisher,
        routeId: routeId,
        versionId: versionId,
        attemptId: effectiveAttemptId,
        occurredAtUtc: now,
        reasonCode: 'rollback:${target.versionId}',
      ),
    );
    if (direct) return _repository.publishDirect(bundle);
    return _repository.submitForReview(
      requestId: _idGenerator.generate(),
      bundle: bundle,
    );
  }

  Future<RoutePublicationAggregate?> _currentFor(
    CreateDraftEntity draft,
  ) async {
    final basedOnVersionId = draft.basedOnPublishedVersionId;
    if (basedOnVersionId != null && basedOnVersionId.trim().isNotEmpty) {
      return _repository.routeByVersionId(basedOnVersionId);
    }
    if (!draft.id.startsWith('loc_')) {
      return _repository.routeById(draft.id);
    }
    return null;
  }

  Future<void> _requireAllowed({
    required String actorId,
    required String draftId,
    required Set<String> capabilities,
    required RouteAuthoringOperation operation,
    RoutePublisherRef? publisher,
  }) async {
    final decision = await _authoringPolicy.authorize(
      RouteAuthorizationRequest(
        actorId: actorId,
        draftId: draftId,
        operation: operation,
        capabilities: capabilities,
        publisherId: publisher?.id,
        publisherType: publisher?.type.name ?? 'user',
      ),
    );
    if (!decision.allowed) {
      throw RoutePublicationAuthorizationException(
        decision.reasonCode ?? 'route_operation_denied',
      );
    }
  }

  static PublishedRouteVersion? _versionById(
    RoutePublicationAggregate? aggregate,
    String versionId,
  ) {
    if (aggregate == null) return null;
    for (final version in aggregate.versions) {
      if (version.versionId == versionId) return version;
    }
    return null;
  }
}
