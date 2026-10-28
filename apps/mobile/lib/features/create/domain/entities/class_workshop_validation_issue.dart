/// A local readiness gap of a Class / Workshop draft (D3.6). It only tells the
/// Creator what is still missing before submit; the server validator stays
/// the authority for every CW-V1 rule and limit.
final class ClassWorkshopValidationIssue {
  const ClassWorkshopValidationIssue({
    required this.code,
    required this.field,
    this.params = const <String, int>{},
  });

  final String code;

  /// Section anchor for the field (`basics`, `learning`, `schedule`, `participation`).
  final String field;

  /// Typed numbers for the message (limits, counts); the UI builds the
  /// text from [code]. No sentence lives in the domain (L4).
  final Map<String, int> params;
}
