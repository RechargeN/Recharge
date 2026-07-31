import '../../domain/entities/route_quality_workflow_data.dart';

class RouteQualityWorkflowMemoryDataSource {
  final Map<String, RouteMapSnapshotCandidate> _candidates =
      <String, RouteMapSnapshotCandidate>{};
  final Map<String, RouteSafetyReport> _reports = <String, RouteSafetyReport>{};

  void saveCandidate(RouteMapSnapshotCandidate candidate) {
    if (!candidate.isValid) {
      throw ArgumentError.value(candidate, 'candidate');
    }
    _candidates[candidate.id] = candidate;
  }

  RouteMapSnapshotCandidate? candidateById(String candidateId) =>
      _candidates[candidateId];

  List<RouteMapSnapshotCandidate> candidatesForRoute(String routeId) {
    final values = _candidates.values
        .where((candidate) => candidate.routeId == routeId)
        .toList(growable: false)
      ..sort((left, right) => left.createdAtUtc.compareTo(right.createdAtUtc));
    return List<RouteMapSnapshotCandidate>.unmodifiable(values);
  }

  List<RouteMapSnapshotCandidate> pendingCandidates() {
    final values = _candidates.values
        .where(
          (candidate) =>
              candidate.decision == RouteCandidateDecision.pending,
        )
        .toList(growable: false)
      ..sort((left, right) => left.createdAtUtc.compareTo(right.createdAtUtc));
    return List<RouteMapSnapshotCandidate>.unmodifiable(values);
  }

  void saveSafetyReport(RouteSafetyReport report) {
    if (!report.isValid) throw ArgumentError.value(report, 'report');
    _reports[report.id] = report;
  }

  RouteSafetyReport? safetyReportById(String reportId) => _reports[reportId];

  List<RouteSafetyReport> safetyReportsForRoute(String routeId) {
    final values = _reports.values
        .where((report) => report.routeId == routeId)
        .toList(growable: false)
      ..sort((left, right) => left.createdAtUtc.compareTo(right.createdAtUtc));
    return List<RouteSafetyReport>.unmodifiable(values);
  }

  List<RouteSafetyReport> openSafetyReports() {
    final values = _reports.values
        .where((report) => report.state == RouteSafetyReportState.open)
        .toList(growable: false)
      ..sort((left, right) => left.createdAtUtc.compareTo(right.createdAtUtc));
    return List<RouteSafetyReport>.unmodifiable(values);
  }
}
