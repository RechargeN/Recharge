import '../domain/entities/event_availability_projection.dart';
import '../domain/entities/event_inventory.dart';
import '../domain/entities/event_validation_issue.dart';
import 'event_admission_section.dart';

class EventInventorySectionDefinition {
  const EventInventorySectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
    required this.previewFeatureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
  final String previewFeatureFlag;
}

const EventInventorySectionDefinition eventInventorySectionDefinition =
    EventInventorySectionDefinition(
      id: 'event_inventory',
      stepId: 'price_participants',
      featureFlag: 'event_admission_configuration',
      previewFeatureFlag: 'event_mock_availability',
    );

class EventInventoryChannelSummary {
  const EventInventoryChannelSummary({
    required this.onsitePoolCount,
    required this.onlinePoolCount,
    required this.anyPoolCount,
  });

  final int onsitePoolCount;
  final int onlinePoolCount;
  final int anyPoolCount;
}

class EventInventorySectionState {
  const EventInventorySectionState({
    required this.enabled,
    required this.mockPreviewEnabled,
    required this.configuration,
    required this.capacityMode,
    required this.capacity,
    required this.channelSummary,
    required this.availabilityPreview,
    required this.refreshingPreview,
    required this.disclosures,
    required this.issues,
  });

  final bool enabled;
  final bool mockPreviewEnabled;
  final EventInventoryConfiguration? configuration;
  final EventCapacityMode capacityMode;
  final int? capacity;
  final EventInventoryChannelSummary channelSummary;
  final EventAvailabilityProjection availabilityPreview;
  final bool refreshingPreview;
  final List<EventAccessCapabilityDisclosure> disclosures;
  final List<EventValidationIssue> issues;

  String? errorFor(String fieldId) {
    for (final EventValidationIssue issue in issues) {
      if (issue.isBlocking && issue.fieldId == fieldId) return issue.message;
    }
    return null;
  }
}
