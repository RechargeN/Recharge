enum ScenarioValidationSeverity { warning, error }

enum ScenarioValidationTarget {
  draft,
  myScenarios,
  unlistedShare,
  publish,
  start,
}

class ScenarioValidationIssue {
  const ScenarioValidationIssue({
    required this.code,
    required this.severity,
    required this.path,
    required this.message,
    this.dayId,
    this.itemId,
    this.legId,
  });

  final String code;
  final ScenarioValidationSeverity severity;
  final String path;
  final String message;
  final String? dayId;
  final String? itemId;
  final String? legId;
}

class ScenarioValidationResult {
  const ScenarioValidationResult({required this.target, required this.issues});

  final ScenarioValidationTarget target;
  final List<ScenarioValidationIssue> issues;

  bool get isValid => issues.every(
    (ScenarioValidationIssue issue) =>
        issue.severity != ScenarioValidationSeverity.error,
  );

  int get warningCount => issues
      .where(
        (ScenarioValidationIssue issue) =>
            issue.severity == ScenarioValidationSeverity.warning,
      )
      .length;
}
