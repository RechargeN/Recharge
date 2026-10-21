/// A local readiness gap of a Class / Workshop draft (D3.6). It only tells the
/// Creator what is still missing before submit; the server validator stays
/// the authority for every CW-V1 rule and limit.
final class ClassWorkshopValidationIssue {
  const ClassWorkshopValidationIssue({
    required this.code,
    required this.field,
    required this.message,
  });

  final String code;

  /// Section anchor for the field (`basics`, `learning`, `schedule`, `participation`).
  final String field;
  final String message;
}
