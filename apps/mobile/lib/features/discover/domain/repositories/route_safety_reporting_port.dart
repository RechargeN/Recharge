enum DiscoverRouteSafetySeverity { information, warning, high, critical }

abstract interface class RouteSafetyReportingPort {
  Future<void> submit({
    required String routeId,
    required String reporterId,
    required String reasonCode,
    required DiscoverRouteSafetySeverity severity,
    String? safeNote,
  });
}
