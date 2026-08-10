import '../domain/entities/event_admission.dart';
import '../domain/entities/event_validation_issue.dart';
import '../domain/usecases/normalize_event_admission_preset_usecase.dart';

class EventAdmissionSectionDefinition {
  const EventAdmissionSectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
}

const EventAdmissionSectionDefinition eventAdmissionSectionDefinition =
    EventAdmissionSectionDefinition(
      id: 'event_admission',
      stepId: 'price_participants',
      featureFlag: 'event_admission_configuration',
    );

enum EventAccessDisclosureCode {
  localConfiguration,
  internalLifecycleUnavailable,
  providerUnavailable,
  waitlistPreviewOnly,
  assignedSeatingUnavailable,
}

class EventAccessCapabilityDisclosure {
  const EventAccessCapabilityDisclosure({
    required this.code,
    required this.message,
    this.blocking = false,
  });

  final EventAccessDisclosureCode code;
  final String message;
  final bool blocking;
}

class EventAdmissionSectionState {
  const EventAdmissionSectionState({
    required this.enabled,
    required this.admission,
    required this.selectedPreset,
    required this.presetPreview,
    required this.legacySuggestion,
    required this.disclosures,
    required this.issues,
  });

  final bool enabled;
  final EventAdmissionDraft? admission;
  final EventAdmissionPreset? selectedPreset;
  final EventAdmissionDraft? presetPreview;
  final EventAdmissionLegacySuggestion? legacySuggestion;
  final List<EventAccessCapabilityDisclosure> disclosures;
  final List<EventValidationIssue> issues;

  String? errorFor(String fieldId) {
    for (final EventValidationIssue issue in issues) {
      if (issue.isBlocking && issue.fieldId == fieldId) return issue.message;
    }
    return null;
  }
}
