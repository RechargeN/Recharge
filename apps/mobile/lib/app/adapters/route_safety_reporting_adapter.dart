import '../../features/create/application/route_quality_workflow_coordinator.dart';
import '../../features/create/domain/entities/route_quality_workflow_data.dart';
import '../../features/discover/domain/repositories/route_safety_reporting_port.dart';

class RouteSafetyReportingAdapter implements RouteSafetyReportingPort {
  const RouteSafetyReportingAdapter(this._workflow);

  final RouteQualityWorkflowCoordinator _workflow;

  @override
  Future<void> submit({
    required String routeId,
    required String reporterId,
    required String reasonCode,
    required DiscoverRouteSafetySeverity severity,
    String? safeNote,
  }) async {
    await _workflow.submitSafetyReport(
      routeId: routeId,
      reporterId: reporterId,
      reasonCode: reasonCode,
      severity: RouteSafetySeverity.values.byName(severity.name),
      safeNote: safeNote,
    );
  }
}
