enum PlaceValidationSeverity { error, warning }

class PlaceValidationIssue {
  const PlaceValidationIssue({
    required this.code,
    required this.severity,
    required this.sectionId,
    required this.messageKey,
    this.fieldId,
    this.messageParams = const <String, Object?>{},
  });

  final String code;
  final PlaceValidationSeverity severity;
  final String sectionId;
  final String? fieldId;
  final String messageKey;
  final Map<String, Object?> messageParams;
}
