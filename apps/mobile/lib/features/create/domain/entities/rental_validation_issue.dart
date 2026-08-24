enum RentalValidationSeverity { error, warning }

/// Mirrors `PlaceValidationIssue` — the richest/most current validation
/// issue shape in this codebase (`sectionId` + i18n-ready `messageKey`,
/// not a raw English `message` string).
class RentalValidationIssue {
  const RentalValidationIssue({
    required this.code,
    this.severity = RentalValidationSeverity.error,
    required this.sectionId,
    this.fieldId,
    required this.messageKey,
    this.messageParams = const <String, Object?>{},
  });

  final String code;
  final RentalValidationSeverity severity;
  final String sectionId;
  final String? fieldId;
  final String messageKey;
  final Map<String, Object?> messageParams;

  bool get isBlocking => severity == RentalValidationSeverity.error;
}
