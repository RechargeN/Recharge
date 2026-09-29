enum ActivityValidationSeverity { error, warning }

class ActivityValidationIssue {
  const ActivityValidationIssue({
    required this.code,
    required this.severity,
    required this.sectionId,
    required this.messageKey,
    this.fieldId,
    this.messageParams = const <String, Object?>{},
  });

  final String code;
  final ActivityValidationSeverity severity;
  final String sectionId; // 'basics' | 'location' | 'whenFor' | 'publish'
  final String? fieldId;
  final String messageKey;
  final Map<String, Object?> messageParams;
}
