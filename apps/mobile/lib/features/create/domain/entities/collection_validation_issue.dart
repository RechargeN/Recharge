enum CollectionValidationSeverity { error, warning }

class CollectionValidationIssue {
  const CollectionValidationIssue({
    required this.code,
    required this.sectionId,
    required this.fieldId,
    this.params = const <String, int>{},
    this.severity = CollectionValidationSeverity.error,
  });

  final String code;
  final String sectionId;
  final String fieldId;

  /// Typed numbers for the message (limits, counts); the UI builds the
  /// text from [code]. No sentence lives in the domain (L4).
  final Map<String, int> params;
  final CollectionValidationSeverity severity;
}
