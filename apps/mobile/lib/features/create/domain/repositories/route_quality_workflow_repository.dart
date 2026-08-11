import '../entities/route_quality_workflow_data.dart';

abstract interface class RouteQualityWorkflowRepository {
  Future<void> saveCandidate(RouteMapSnapshotCandidate candidate);

  Future<RouteMapSnapshotCandidate?> candidateById(String candidateId);

  Future<List<RouteMapSnapshotCandidate>> candidatesForRoute(String routeId);

  Future<List<RouteMapSnapshotCandidate>> pendingCandidates();

  Future<void> saveSafetyReport(RouteSafetyReport report);

  Future<RouteSafetyReport?> safetyReportById(String reportId);

  Future<List<RouteSafetyReport>> safetyReportsForRoute(String routeId);

  Future<List<RouteSafetyReport>> openSafetyReports();
}
