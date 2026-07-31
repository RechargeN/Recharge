import '../../../core/id/id_generator.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/route_draft_data.dart';
import '../domain/entities/route_quality_data.dart';
import '../domain/entities/route_quality_workflow_data.dart';
import '../domain/entities/route_publication_data.dart';
import '../domain/repositories/route_authoring_policy.dart';
import '../domain/repositories/route_geometry_diff_builder.dart';
import '../domain/repositories/route_publication_repository.dart';
import '../domain/repositories/route_quality_calculator.dart';
import '../domain/repositories/route_quality_workflow_repository.dart';
import '../domain/usecases/build_route_geometry_diff_usecase.dart';
import '../domain/usecases/calculate_route_quality_usecase.dart';

class RouteQualityWorkflowException implements Exception {
  const RouteQualityWorkflowException(this.reasonCode);

  final String reasonCode;

  @override
  String toString() => 'Route quality workflow failed: $reasonCode';
}

class RouteQualityWorkflowCoordinator {
  RouteQualityWorkflowCoordinator({
    required IdGenerator idGenerator,
    required RouteQualityWorkflowRepository workflowRepository,
    required RoutePublicationRepository publicationRepository,
    required RouteAuthoringPolicy authoringPolicy,
    RouteGeometryDiffBuilder diffBuilder =
        const BuildRouteGeometryDiffUseCase(),
    RouteQualityCalculator qualityCalculator =
        const CalculateRouteQualityUseCase(),
    DateTime Function()? clock,
  }) : _idGenerator = idGenerator,
       _workflowRepository = workflowRepository,
       _publicationRepository = publicationRepository,
       _authoringPolicy = authoringPolicy,
       _diffBuilder = diffBuilder,
       _qualityCalculator = qualityCalculator,
       _clock = clock ?? DateTime.now;

  final IdGenerator _idGenerator;
  final RouteQualityWorkflowRepository _workflowRepository;
  final RoutePublicationRepository _publicationRepository;
  final RouteAuthoringPolicy _authoringPolicy;
  final RouteGeometryDiffBuilder _diffBuilder;
  final RouteQualityCalculator _qualityCalculator;
  final DateTime Function() _clock;

  Future<CreateDraftEntity> verifyDraft({
    required CreateDraftEntity draft,
    required String actorId,
    required Set<String> capabilities,
    required RouteVerificationKind kind,
    Iterable<String> evidenceMediaIds = const <String>[],
    String? note,
  }) async {
    final route = draft.routeData;
    if (route == null || draft.objectType != CreateObjectType.route) {
      throw const RouteQualityWorkflowException('route_draft_required');
    }
    await _authorize(
      actorId: actorId,
      draftId: draft.id,
      operation: RouteAuthoringOperation.verifyQuality,
      capabilities: capabilities,
    );
    final now = _nowUtc();
    final calculated = _qualityCalculator.calculate(
      route: route,
      calculatedAtUtc: now,
    );
    final verification = RouteVerificationRecordDraft(
      id: _idGenerator.generate(),
      kind: kind,
      actorId: actorId,
      geometryRevision: route.geometryRevision,
      verifiedAtUtc: now,
      evidenceMediaIds: evidenceMediaIds,
      note: _trimmedOrNull(note),
    );
    final nextQuality = calculated.copyWith(
      verifications: <RouteVerificationRecordDraft>[
        ...calculated.verifications,
        verification,
      ],
    );
    return draft.copyWith(
      routeData: route.copyWith(
        revision: route.revision + 1,
        quality: nextQuality,
      ),
      updatedAtUtc: now,
    );
  }

  Future<RouteMapSnapshotCandidate> createCandidate({
    required String actorId,
    required Set<String> capabilities,
    required String routeId,
    required String baseVersionId,
    required String sourceSnapshotId,
    required String sourceAttribution,
    required RouteDraftData candidateDraft,
  }) async {
    await _authorize(
      actorId: actorId,
      draftId: routeId,
      operation: RouteAuthoringOperation.reviewMapCandidate,
      capabilities: capabilities,
    );
    final base = await _version(baseVersionId);
    if (base.routeId != routeId) {
      throw const RouteQualityWorkflowException('candidate_route_mismatch');
    }
    final now = _nowUtc();
    final candidateWithQuality = candidateDraft.copyWith(
      quality: _qualityCalculator.calculate(
        route: candidateDraft,
        calculatedAtUtc: now,
      ),
    );
    final candidate = RouteMapSnapshotCandidate(
      id: _idGenerator.generate(),
      routeId: routeId,
      baseVersionId: baseVersionId,
      sourceSnapshotId: sourceSnapshotId,
      sourceAttribution: sourceAttribution,
      candidateDraft: candidateWithQuality,
      diff: _diffBuilder.build(
        baseVersion: base,
        candidate: candidateWithQuality,
      ),
      decision: RouteCandidateDecision.pending,
      createdAtUtc: now,
    );
    await _workflowRepository.saveCandidate(candidate);
    return candidate;
  }

  Future<RouteCandidateDecisionResult> decideCandidate({
    required String candidateId,
    required RouteCandidateDecision decision,
    required String actorId,
    required Set<String> capabilities,
    String? reasonCode,
  }) async {
    if (decision == RouteCandidateDecision.pending) {
      throw const RouteQualityWorkflowException('candidate_decision_required');
    }
    final candidate = await _workflowRepository.candidateById(candidateId);
    if (candidate == null) {
      throw const RouteQualityWorkflowException('candidate_not_found');
    }
    if (candidate.decision != RouteCandidateDecision.pending) {
      return RouteCandidateDecisionResult(candidate: candidate);
    }
    await _authorize(
      actorId: actorId,
      draftId: candidate.routeId,
      operation: RouteAuthoringOperation.reviewMapCandidate,
      capabilities: capabilities,
    );
    final reason = _trimmedOrNull(reasonCode);
    if (decision != RouteCandidateDecision.accepted && reason == null) {
      throw const RouteQualityWorkflowException(
        'candidate_decision_reason_required',
      );
    }
    final now = _nowUtc();
    PublishedRouteVersion? acceptedBase;
    if (decision == RouteCandidateDecision.accepted) {
      acceptedBase = await _version(candidate.baseVersionId);
      final active = await _publicationRepository.routeById(candidate.routeId);
      if (active?.activeVersionId != candidate.baseVersionId) {
        throw const RouteQualityWorkflowException(
          'candidate_base_version_changed',
        );
      }
    }
    final decided = candidate.copyWith(
      decision: decision,
      decidedAtUtc: now,
      decidedBy: actorId,
      reasonCode: reason,
    );
    await _workflowRepository.saveCandidate(decided);
    if (decision != RouteCandidateDecision.accepted) {
      return RouteCandidateDecisionResult(candidate: decided);
    }

    final base = acceptedBase!;
    final revisionRoute = candidate.candidateDraft.copyWith(
      revision: (base.contentSnapshot.routeData?.revision ?? 0) + 1,
    );
    final revision = base.contentSnapshot.copyWith(
      id: _idGenerator.generate(),
      basedOnPublishedVersionId: base.versionId,
      routeData: revisionRoute,
      draftStatus: DraftStatus.draft,
      moderationStatus: ModerationStatus.none,
      publishStatus: PublishStatus.draft,
      updatedAtUtc: now,
      clearPublishedAtUtc: true,
    );
    return RouteCandidateDecisionResult(
      candidate: decided,
      revisionDraft: revision,
    );
  }

  Future<RouteSafetyReport> submitSafetyReport({
    required String routeId,
    required String reporterId,
    required String reasonCode,
    required RouteSafetySeverity severity,
    String? safeNote,
  }) async {
    if (reporterId.trim().isEmpty || reasonCode.trim().isEmpty) {
      throw const RouteQualityWorkflowException('safety_report_invalid');
    }
    final aggregate = await _publicationRepository.routeById(routeId);
    final active = aggregate?.activeVersion;
    if (active == null) {
      throw const RouteQualityWorkflowException('published_route_not_found');
    }
    final now = _nowUtc();
    final report = RouteSafetyReport(
      id: _idGenerator.generate(),
      routeId: routeId,
      versionId: active.versionId,
      reporterId: reporterId,
      reasonCode: reasonCode.trim(),
      severity: severity,
      state: RouteSafetyReportState.open,
      createdAtUtc: now,
      safeNote: _trimmedOrNull(safeNote),
    );
    await _workflowRepository.saveSafetyReport(report);

    final status = switch (severity) {
      RouteSafetySeverity.critical => RouteLifecycleStatus.suspended,
      RouteSafetySeverity.high => RouteLifecycleStatus.needsReview,
      RouteSafetySeverity.warning || RouteSafetySeverity.information => null,
    };
    if (status != null) {
      await _publicationRepository.setLifecycle(
        routeId: routeId,
        status: status,
        actorId: reporterId,
        attemptId: _idGenerator.generate(),
        reasonCode: reasonCode.trim(),
        changedAtUtc: now,
      );
    }
    return report;
  }

  Future<RouteSafetyReport> decideSafetyReport({
    required String reportId,
    required RouteSafetyReportState state,
    required String actorId,
    required Set<String> capabilities,
    required String reasonCode,
    bool restoreRoute = false,
  }) async {
    if (state == RouteSafetyReportState.open || reasonCode.trim().isEmpty) {
      throw const RouteQualityWorkflowException('safety_decision_invalid');
    }
    final report = await _workflowRepository.safetyReportById(reportId);
    if (report == null) {
      throw const RouteQualityWorkflowException('safety_report_not_found');
    }
    await _authorize(
      actorId: actorId,
      draftId: report.routeId,
      operation: RouteAuthoringOperation.moderateSafety,
      capabilities: capabilities,
    );
    final now = _nowUtc();
    final decided = report.copyWith(
      state: state,
      decidedAtUtc: now,
      decidedBy: actorId,
      decisionReasonCode: reasonCode.trim(),
    );
    await _workflowRepository.saveSafetyReport(decided);

    if (restoreRoute) {
      final reports = await _workflowRepository.safetyReportsForRoute(
        report.routeId,
      );
      final hasOpenCritical = reports.any(
        (value) =>
            value.state == RouteSafetyReportState.open &&
            value.severity == RouteSafetySeverity.critical,
      );
      if (hasOpenCritical) {
        throw const RouteQualityWorkflowException(
          'open_critical_report_prevents_restore',
        );
      }
      await _publicationRepository.setLifecycle(
        routeId: report.routeId,
        status: RouteLifecycleStatus.active,
        actorId: actorId,
        attemptId: _idGenerator.generate(),
        reasonCode: reasonCode.trim(),
        changedAtUtc: now,
      );
    }
    return decided;
  }

  Future<List<RouteMapSnapshotCandidate>> candidatesForRoute(String routeId) =>
      _workflowRepository.candidatesForRoute(routeId);

  Future<List<RouteMapSnapshotCandidate>> pendingCandidates() =>
      _workflowRepository.pendingCandidates();

  Future<List<RouteSafetyReport>> safetyReportsForRoute(String routeId) =>
      _workflowRepository.safetyReportsForRoute(routeId);

  Future<List<RouteSafetyReport>> openSafetyReports() =>
      _workflowRepository.openSafetyReports();

  Future<PublishedRouteVersion> _version(String versionId) async {
    final aggregate = await _publicationRepository.routeByVersionId(versionId);
    if (aggregate == null) {
      throw const RouteQualityWorkflowException(
        'published_route_version_not_found',
      );
    }
    for (final version in aggregate.versions) {
      if (version.versionId == versionId) return version;
    }
    throw const RouteQualityWorkflowException(
      'published_route_version_not_found',
    );
  }

  Future<void> _authorize({
    required String actorId,
    required String draftId,
    required RouteAuthoringOperation operation,
    required Set<String> capabilities,
  }) async {
    final decision = await _authoringPolicy.authorize(
      RouteAuthorizationRequest(
        actorId: actorId,
        draftId: draftId,
        operation: operation,
        capabilities: capabilities,
        publisherId: actorId,
      ),
    );
    if (!decision.allowed) {
      throw RouteQualityWorkflowException(
        decision.reasonCode ?? 'route_quality_unauthorized',
      );
    }
  }

  DateTime _nowUtc() => _clock().toUtc();

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
