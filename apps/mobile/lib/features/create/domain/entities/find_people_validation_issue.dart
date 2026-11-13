enum FindPeopleValidationSeverity { error, warning }

class FindPeopleValidationIssue {
  const FindPeopleValidationIssue({
    required this.code,
    required this.sectionId,
    required this.fieldId,
    this.params = const <String, int>{},
    this.severity = FindPeopleValidationSeverity.error,
  });

  final String code;
  final String sectionId;
  final String fieldId;

  /// Typed numbers for the message (limits, counts); the UI builds the
  /// text from [code]. No sentence lives in the domain (L4).
  final Map<String, int> params;
  final FindPeopleValidationSeverity severity;
}
