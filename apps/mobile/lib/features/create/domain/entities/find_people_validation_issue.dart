enum FindPeopleValidationSeverity { error, warning }

class FindPeopleValidationIssue {
  const FindPeopleValidationIssue({
    required this.code,
    required this.sectionId,
    required this.fieldId,
    required this.message,
    this.severity = FindPeopleValidationSeverity.error,
  });

  final String code;
  final String sectionId;
  final String fieldId;
  final String message;
  final FindPeopleValidationSeverity severity;
}
