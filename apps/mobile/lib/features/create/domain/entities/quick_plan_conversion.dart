import '../../../../shared/primitives/money/currency_code.dart';
import '../../../../shared/primitives/money/money.dart';

import 'scenario_draft_data.dart';

enum QuickPlanConversionIssueSeverity { warning, error }

enum QuickPlanConversionIssueCode {
  sourceNotFoundOrForbidden,
  sourceRevisionMismatch,
  stopNotFound,
  stopUnavailable,
  selectionEmpty,
  legacyStopBecamePrivateCustomLocation,
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
    required this.price,
    required this.available,
    this.requesterPrivateNote,
  });

  final String id;
  final String title;
  final int? durationMinutes;
  final double latitude;
  final double longitude;
  final bool isFree;
  final Money? price;
  final bool available;
  final String? requesterPrivateNote;
}

class QuickPlanConversionSnapshot {
  const QuickPlanConversionSnapshot({
    required this.id,
    required this.revision,
    required this.ownerId,
    required this.title,
    required this.timezoneId,
    required this.currency,
    required this.stops,
    required this.readableByUserIds,
  });

  final String id;
  final int revision;
  final String ownerId;
  final String title;
  final String timezoneId;
  final CurrencyCode currency;
  final List<QuickPlanConversionStopSnapshot> stops;
  final Set<String> readableByUserIds;

  String get currencyCode => currency.value;
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
