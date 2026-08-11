import '../repositories/route_safety_reporting_port.dart';

class SubmitRouteSafetyReportUseCase {
  const SubmitRouteSafetyReportUseCase(this._port);

  final RouteSafetyReportingPort _port;

  Future<void> call({
    required String routeId,
    required String reporterId,
    required String reasonCode,
    required DiscoverRouteSafetySeverity severity,
    String? safeNote,
  }) => _port.submit(
    routeId: routeId,
    reporterId: reporterId,
    reasonCode: reasonCode,
    severity: severity,
    safeNote: safeNote,
  );
}
