enum EventValidationSeverity { blocking, warning }

class EventValidationIssue {
  const EventValidationIssue({
    required this.code,
    required this.fieldId,
    required this.step,
    this.severity = EventValidationSeverity.blocking,
  });

  final String code;
  final String fieldId;
  final int step;
  final EventValidationSeverity severity;

  bool get isBlocking => severity == EventValidationSeverity.blocking;
}
