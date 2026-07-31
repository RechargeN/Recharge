import '../../domain/entities/route_quality_workflow_data.dart';
import '../../domain/repositories/route_quality_workflow_repository.dart';
import '../datasources/route_quality_workflow_memory_datasource.dart';

class RouteQualityWorkflowRepositoryImpl
    implements RouteQualityWorkflowRepository {
  const RouteQualityWorkflowRepositoryImpl(this._dataSource);

  final RouteQualityWorkflowMemoryDataSource _dataSource;

  @override
  Future<void> saveCandidate(RouteMapSnapshotCandidate candidate) async {
    _dataSource.saveCandidate(candidate);
  }

  @override
  Future<RouteMapSnapshotCandidate?> candidateById(String candidateId) async =>
      _dataSource.candidateById(candidateId);

  @override
  Future<List<RouteMapSnapshotCandidate>> candidatesForRoute(
    String routeId,
  ) async => _dataSource.candidatesForRoute(routeId);

  @override
  Future<List<RouteMapSnapshotCandidate>> pendingCandidates() async =>
      _dataSource.pendingCandidates();

  @override
  Future<void> saveSafetyReport(RouteSafetyReport report) async {
    _dataSource.saveSafetyReport(report);
  }

  @override
  Future<RouteSafetyReport?> safetyReportById(String reportId) async =>
      _dataSource.safetyReportById(reportId);

  @override
  Future<List<RouteSafetyReport>> safetyReportsForRoute(String routeId) async =>
      _dataSource.safetyReportsForRoute(routeId);

  @override
  Future<List<RouteSafetyReport>> openSafetyReports() async =>
      _dataSource.openSafetyReports();
}
