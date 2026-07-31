enum RouteValidationSeverity { blocking, warning }

enum RouteValidationRemediation { fix, retry, review, accept }

class RouteValidationLocation {
  const RouteValidationLocation({
    required this.sectionId,
    this.fieldId,
    this.segmentId,
    this.waypointId,
  });

  final String sectionId;
  final String? fieldId;
  final String? segmentId;
  final String? waypointId;

  String get stableKey => <String>[
    sectionId,
    fieldId ?? '',
    segmentId ?? '',
    waypointId ?? '',
  ].join(':');
}

class RouteValidationIssue {
  RouteValidationIssue({
    required this.code,
    required this.severity,
    required this.location,
    required this.remediation,
    String? messageKey,
    Map<String, num> safeMetrics = const <String, num>{},
  }) : messageKey = messageKey ?? 'route.validation.$code',
       safeMetrics = Map<String, num>.unmodifiable(safeMetrics);

  final String code;
  final RouteValidationSeverity severity;
  final RouteValidationLocation location;
  final RouteValidationRemediation remediation;
  final String messageKey;
  final Map<String, num> safeMetrics;

  String get stableId => '$code:${location.stableKey}';
}

class RouteReadiness {
  RouteReadiness(Iterable<RouteValidationIssue> issues)
    : issues = List<RouteValidationIssue>.unmodifiable(issues);

  final List<RouteValidationIssue> issues;

  bool get canPublish => blockingIssues.isEmpty;

  List<RouteValidationIssue> get blockingIssues => List.unmodifiable(
    issues.where(
      (RouteValidationIssue issue) =>
          issue.severity == RouteValidationSeverity.blocking,
    ),
  );

  List<RouteValidationIssue> get warnings => List.unmodifiable(
    issues.where(
      (RouteValidationIssue issue) =>
          issue.severity == RouteValidationSeverity.warning,
    ),
  );
}
