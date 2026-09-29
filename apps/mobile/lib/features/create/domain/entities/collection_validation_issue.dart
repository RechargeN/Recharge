enum CollectionValidationSeverity { error, warning }

class CollectionValidationIssue {
  const CollectionValidationIssue({
    required this.code,
    required this.sectionId,
    required this.fieldId,
    required this.message,
    this.severity = CollectionValidationSeverity.error,
  });

  final String code;
  final String sectionId;
  final String fieldId;
  final String message;
  final CollectionValidationSeverity severity;
}
