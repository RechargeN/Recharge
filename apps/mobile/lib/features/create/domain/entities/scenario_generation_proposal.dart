import 'scenario_draft_data.dart';
import 'scenario_item_draft.dart';
import 'scenario_logistics_draft.dart';

enum ScenarioGenerationMode { localDemo }

enum ScenarioGenerationConfidence { catalogSnapshot, estimated, unresolved }

enum ScenarioGenerationIssueCode {
  travelNotCalculated,
  liveAvailabilityNotChecked,
  costsUnknown,
  noCandidates,
}

class ScenarioGenerationRequest {
  const ScenarioGenerationRequest({
    required this.prompt,
    required this.marketCityId,
    required this.timezoneId,
    required this.currencyCode,
    required this.sourceRevision,
    required this.format,
    required this.peopleCount,
    required this.partyKind,
    required this.pace,
    required this.travelMode,
    required this.existingCatalogObjectIds,
  });

  final String prompt;
  final String marketCityId;
  final String timezoneId;
  final String currencyCode;
  final int sourceRevision;
  final ScenarioFormat format;
  final int peopleCount;
  final ScenarioPartyKind partyKind;
  final ScenarioPace pace;
  final ScenarioTravelMode travelMode;
  final Set<String> existingCatalogObjectIds;
}

class ScenarioGenerationContext {
  const ScenarioGenerationContext({
    required this.marketLabel,
    required this.formatLabel,
    required this.partyLabel,
    required this.paceLabel,
    required this.travelLabel,
    required this.intentLabels,
  });

  final String marketLabel;
  final String formatLabel;
  final String partyLabel;
  final String paceLabel;
  final String travelLabel;
  final List<String> intentLabels;

  List<String> get displayLabels => <String>[
    if (marketLabel.isNotEmpty) marketLabel,
    formatLabel,
    partyLabel,
    paceLabel,
    travelLabel,
    ...intentLabels,
  ];
}

class ScenarioGeneratedCatalogItem {
  const ScenarioGeneratedCatalogItem({
    required this.objectId,
    required this.objectType,
    required this.title,
    required this.subtitle,
    required this.durationMinutes,
    required this.reason,
    required this.confidence,
    this.coverMediaId,
    this.publisherId,
  });

  final String objectId;
  final ScenarioCatalogObjectType objectType;
  final String title;
  final String subtitle;
  final int durationMinutes;
  final String reason;
  final ScenarioGenerationConfidence confidence;
  final String? coverMediaId;
  final String? publisherId;
}

class ScenarioGenerationEvidence {
  const ScenarioGenerationEvidence({
    required this.objectId,
    required this.label,
    required this.confidence,
  });

  final String objectId;
  final String label;
  final ScenarioGenerationConfidence confidence;
}

class ScenarioGenerationIssue {
  const ScenarioGenerationIssue({required this.code, required this.message});

  final ScenarioGenerationIssueCode code;
  final String message;
}

class ScenarioGenerationProposal {
  const ScenarioGenerationProposal({
    required this.id,
    required this.mode,
    required this.sourceRevision,
    required this.generatedAtUtc,
    required this.context,
    required this.items,
    required this.evidence,
    required this.issues,
    required this.activityMinutes,
  });

  final String id;
  final ScenarioGenerationMode mode;
  final int sourceRevision;
  final DateTime generatedAtUtc;
  final ScenarioGenerationContext context;
  final List<ScenarioGeneratedCatalogItem> items;
  final List<ScenarioGenerationEvidence> evidence;
  final List<ScenarioGenerationIssue> issues;
  final int activityMinutes;

  bool get canApply => items.isNotEmpty;
}
