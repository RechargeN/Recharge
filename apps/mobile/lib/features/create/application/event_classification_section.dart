import '../domain/entities/event_classification.dart';
import '../domain/entities/event_validation_issue.dart';
import '../domain/usecases/suggest_event_classification_usecase.dart';

class EventClassificationSectionDefinition {
  const EventClassificationSectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
}

const EventClassificationSectionDefinition eventClassificationSection =
    EventClassificationSectionDefinition(
      id: 'event_classification',
      stepId: 'basics_media',
      featureFlag: 'event_classification_ui',
    );

class EventClassificationSectionState {
  const EventClassificationSectionState({
    required this.enabled,
    required this.classification,
    required this.suggestion,
    required this.issues,
  });

  final bool enabled;
  final EventClassificationDraft? classification;
  final EventClassificationSuggestion? suggestion;
  final List<EventValidationIssue> issues;

  String? errorFor(String fieldId) {
    for (final EventValidationIssue issue in issues) {
      if (issue.isBlocking && issue.fieldId == fieldId) return issue.message;
    }
    return null;
  }

  bool get canAddParticipationMode =>
      (classification?.additionalParticipationModes.length ?? 0) < 3;
}

class EventArchetypeChangeImpact {
  const EventArchetypeChangeImpact({
    required this.previous,
    required this.next,
    required this.clearsOtherReason,
  });

  final EventArchetype? previous;
  final EventArchetype next;
  final bool clearsOtherReason;

  Set<String> get affectedFieldIds => <String>{
    'eventArchetype',
    if (clearsOtherReason) 'eventArchetypeOtherReason',
  };
}
