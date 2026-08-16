import 'scenario_draft_data.dart';
import 'scenario_item_draft.dart';

enum QuickPlanConversionIssueSeverity { warning, error }

enum QuickPlanConversionIssueCode {
  sourceNotFoundOrForbidden,
  sourceRevisionMismatch,
  stopNotFound,
  stopUnavailable,
  selectionEmpty,
  legacySourceIdentityMissing,
  privateNoteNotCopied,
}

class QuickPlanConversionIssue {
  const QuickPlanConversionIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.quickPlanStopId,
  });

  final QuickPlanConversionIssueCode code;
  final QuickPlanConversionIssueSeverity severity;
  final String message;
  final String? quickPlanStopId;
}

class QuickPlanConversionStopSnapshot {
  const QuickPlanConversionStopSnapshot({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.latitude,
    required this.longitude,
    required this.isFree,
    required this.priceMinorUnits,
    required this.available,
    this.distanceKm,
    this.sourceObjectId,
    this.sourceObjectType,
    this.requesterPrivateNote,
  });

  final String id;
  final String title;
  final int? durationMinutes;
  final double latitude;
  final double longitude;
  final bool isFree;
  final int? priceMinorUnits;
  final bool available;
  final double? distanceKm;
  final String? sourceObjectId;
  final ScenarioCatalogObjectType? sourceObjectType;
  final String? requesterPrivateNote;
}

class QuickPlanConversionSnapshot {
  const QuickPlanConversionSnapshot({
    required this.id,
    required this.revision,
    required this.ownerId,
    required this.title,
    required this.timezoneId,
    required this.currencyCode,
    required this.stops,
    required this.readableByUserIds,
  });

  final String id;
  final int revision;
  final String ownerId;
  final String title;
  final String timezoneId;
  final String currencyCode;
  final List<QuickPlanConversionStopSnapshot> stops;
  final Set<String> readableByUserIds;
}

class ExpandQuickPlanToScenarioRequest {
  const ExpandQuickPlanToScenarioRequest({
    required this.quickPlanId,
    required this.expectedQuickPlanRevision,
    required this.selectedStopIds,
    required this.copyPrivateNotes,
    required this.requesterId,
    this.continueWithLatestSnapshot = false,
  });

  final String quickPlanId;
  final int expectedQuickPlanRevision;
  final Set<String> selectedStopIds;
  final bool copyPrivateNotes;
  final String requesterId;
  final bool continueWithLatestSnapshot;
}

class ExpandQuickPlanToScenarioResult {
  const ExpandQuickPlanToScenarioResult({
    required this.scenario,
    required this.issues,
    required this.quickPlanStopIdToScenarioItemId,
    required this.privateNotesByScenarioItemId,
    required this.sourceRevision,
  });

  final ScenarioDraftData? scenario;
  final List<QuickPlanConversionIssue> issues;
  final Map<String, String> quickPlanStopIdToScenarioItemId;
  final Map<String, String> privateNotesByScenarioItemId;
  final int? sourceRevision;

  bool get succeeded => scenario != null;
  bool get requiresRevisionConfirmation => issues.any(
    (QuickPlanConversionIssue issue) =>
        issue.code == QuickPlanConversionIssueCode.sourceRevisionMismatch &&
        issue.severity == QuickPlanConversionIssueSeverity.error,
  );
}
