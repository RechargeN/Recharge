import '../entities/event_classification.dart';
import '../entities/event_validation_issue.dart';

class ValidateEventClassificationUseCase {
  const ValidateEventClassificationUseCase();

  List<EventValidationIssue> call(EventClassificationDraft? classification) {
    final List<EventValidationIssue> issues = <EventValidationIssue>[];
    if (classification == null || classification.archetype == null) {
      issues.add(
        const EventValidationIssue(
          code: 'event_archetype_required',
          fieldId: 'eventArchetype',
          step: 0,
          message: 'Choose how this event is organized.',
        ),
      );
    }
    if (classification == null ||
        classification.primaryParticipationMode == null) {
      issues.add(
        const EventValidationIssue(
          code: 'primary_participation_required',
          fieldId: 'primaryParticipationMode',
          step: 0,
          message: 'Choose the attendee\'s primary role.',
        ),
      );
    }
    if (classification != null &&
        classification.additionalParticipationModes.length > 3) {
      issues.add(
        const EventValidationIssue(
          code: 'additional_participation_limit',
          fieldId: 'additionalParticipationModes',
          step: 0,
          message: 'Choose no more than three additional attendee roles.',
        ),
      );
    }
    if (classification != null &&
        classification.additionalParticipationModes.contains(
          classification.primaryParticipationMode,
        )) {
      issues.add(
        const EventValidationIssue(
          code: 'participation_mode_duplicate',
          fieldId: 'additionalParticipationModes',
          step: 0,
          message: 'The primary role cannot also be an additional role.',
        ),
      );
    }
    if (classification?.archetype == EventArchetype.other &&
        (classification?.otherReason?.trim().isEmpty ?? true)) {
      issues.add(
        const EventValidationIssue(
          code: 'event_archetype_other_reason_required',
          fieldId: 'eventArchetypeOtherReason',
          step: 0,
          message: 'Explain the event mechanics when choosing Other.',
        ),
      );
    }
    if (classification?.archetype == EventArchetype.other &&
        (classification?.otherReason?.trim().isNotEmpty ?? false)) {
      issues.add(
        const EventValidationIssue(
          code: 'event_archetype_other_moderation_review',
          fieldId: 'eventArchetype',
          step: 0,
          message: 'Other mechanics will be reviewed after submission.',
          severity: EventValidationSeverity.warning,
        ),
      );
    }
    return List<EventValidationIssue>.unmodifiable(issues);
  }
}
