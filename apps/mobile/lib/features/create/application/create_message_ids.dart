import '../domain/entities/event_validation_issue.dart';

/// L4: stable message ids for Create field errors (`CreateState
/// .validationErrors` values and section field errors). An id is
/// `<family>.validation.<code>` (or `event.admission_preset.<fieldId>`); the
/// UI resolves it to text with `createFieldErrorText`. Ids never carry
/// sentences or user content.
abstract final class CreateMessageIds {
  static const String event = 'event.validation.';
  static const String eventAdmissionPreset = 'event.admission_preset.';
  static const String findPeople = 'find_people.validation.';
  static const String scenario = 'scenario.validation.';
  static const String collection = 'collection.validation.';
  static const String classWorkshop = 'class_workshop.validation.';
  static const String availability = 'availability.validation.';
  static const String form = 'create.validation.';

  /// The admission preset refusal shares one code; its field picks the text.
  static const String admissionPresetChoiceRequired =
      'admission_preset_choice_required';
}

/// The field-error id of one Event check.
String eventIssueMessageId(EventValidationIssue issue) =>
    issue.code == CreateMessageIds.admissionPresetChoiceRequired
    ? '${CreateMessageIds.eventAdmissionPreset}${issue.fieldId}'
    : '${CreateMessageIds.event}${issue.code}';
