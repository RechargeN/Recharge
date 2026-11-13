import '../domain/entities/event_admission.dart';
import '../domain/entities/event_validation_issue.dart';
import '../domain/usecases/normalize_event_admission_preset_usecase.dart';
import 'create_message_ids.dart';

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

/// L4: which explanation a disclosure shows; the UI turns it into text.
enum EventAccessDisclosureTopic {
  localConfiguration,
  internalNotActive,
  internalLocalStand,
  providerConfirmationNotConnected,
  waitlistConfigurationOnly,
  capacityIsConfiguration,
  externalInventoryUnverified,
  assignedSeatingUnavailable,
}

class EventAccessCapabilityDisclosure {
  const EventAccessCapabilityDisclosure({
    required this.code,
    required this.topic,
    this.blocking = false,
  });

  final EventAccessDisclosureCode code;
  final EventAccessDisclosureTopic topic;
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

  /// The field-error message id (L4: the UI resolves it to text).
  String? errorIdFor(String fieldId) {
    for (final EventValidationIssue issue in issues) {
      if (issue.isBlocking && issue.fieldId == fieldId) {
        return eventIssueMessageId(issue);
      }
    }
    return null;
  }
}
