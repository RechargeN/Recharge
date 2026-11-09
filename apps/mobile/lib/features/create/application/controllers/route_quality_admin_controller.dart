import 'package:flutter/foundation.dart';

import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/route_quality_workflow_data.dart';
import '../route_quality_workflow_coordinator.dart';

class RouteQualityAdminController extends ChangeNotifier {
  RouteQualityAdminController(this._coordinator);

  final RouteQualityWorkflowCoordinator _coordinator;

  bool loading = false;
  String? errorCode;
  List<RouteMapSnapshotCandidate> candidates =
      const <RouteMapSnapshotCandidate>[];
  List<RouteSafetyReport> reports = const <RouteSafetyReport>[];
  CreateDraftEntity? lastCreatedRevision;

  Future<void> load({
    String actorId = '',
    Set<String> capabilities = const {},
  }) async {
    loading = true;
    candidates = [];
    reports = [];
    lastCreatedRevision = null;
    errorCode = null;
    notifyListeners();
    try {
      candidates = capabilities.contains('manage.route')
          ? await _coordinator.pendingCandidates(
              actorId: actorId,
              capabilities: capabilities,
            )
          : [];
      reports = capabilities.contains('moderate.route')
          ? await _coordinator.openSafetyReports(
              actorId: actorId,
              capabilities: capabilities,
            )
          : [];
    } on Object {
      candidates = [];
      reports = [];
      lastCreatedRevision = null;
      errorCode = 'route_quality_queue_failed';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> decideCandidate({
    required String candidateId,
    required RouteCandidateDecision decision,
    required String actorId,
    required Set<String> capabilities,
    String? reasonCode,
  }) async {
    loading = true;
    candidates = [];
    reports = [];
    lastCreatedRevision = null;
    errorCode = null;
    notifyListeners();
    try {
      final result = await _coordinator.decideCandidate(
        candidateId: candidateId,
        decision: decision,
        actorId: actorId,
        capabilities: capabilities,
        reasonCode: reasonCode,
      );
      lastCreatedRevision = result.revisionDraft;
      await load(actorId: actorId, capabilities: capabilities);
    } on RouteQualityWorkflowException catch (error) {
      errorCode = error.reasonCode;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> decideSafety({
    required String reportId,
    required RouteSafetyReportState state,
    required String actorId,
    required Set<String> capabilities,
    required String reasonCode,
    bool restoreRoute = false,
  }) async {
    loading = true;
    candidates = [];
    reports = [];
    lastCreatedRevision = null;
    errorCode = null;
    notifyListeners();
    try {
      await _coordinator.decideSafetyReport(
        reportId: reportId,
        state: state,
        actorId: actorId,
        capabilities: capabilities,
        reasonCode: reasonCode,
        restoreRoute: restoreRoute,
      );
      await load(actorId: actorId, capabilities: capabilities);
    } on RouteQualityWorkflowException catch (error) {
      errorCode = error.reasonCode;
      loading = false;
      notifyListeners();
    }
  }
}
