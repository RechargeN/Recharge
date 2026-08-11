import 'scenario_draft_data.dart';
import 'scenario_item_draft.dart';
import 'scenario_transit_schedule.dart';

enum ScenarioTransitMutationFailure {
  revisionConflict,
  invalidSelection,
  missingTarget,
  targetNotOfficial,
}

class ScenarioTransitMutationRequest {
  const ScenarioTransitMutationRequest({
    required this.draft,
    required this.expectedRevision,
    required this.option,
    this.replaceItemId,
  });

  final ScenarioDraftData draft;
  final int expectedRevision;
  final ScenarioTransitServiceOption option;
  final String? replaceItemId;
}

class ScenarioTransitMutationResult {
  const ScenarioTransitMutationResult.accepted({
    required this.draft,
    required this.itemId,
  }) : accepted = true,
       failure = null;

  const ScenarioTransitMutationResult.rejected({
    required this.draft,
    required this.failure,
  }) : accepted = false,
       itemId = null;

  final bool accepted;
  final ScenarioDraftData draft;
  final String? itemId;
  final ScenarioTransitMutationFailure? failure;
}

enum ScenarioTransitRecheckStatus {
  unchanged,
  changed,
  notFound,
  unavailable,
  invalidSnapshot,
}

class ScenarioTransitSnapshotDiff {
  const ScenarioTransitSnapshotDiff({
    required this.fieldCode,
    required this.before,
    required this.after,
  });

  final String fieldCode;
  final String? before;
  final String? after;
}

class ScenarioTransitRecheckResult {
  const ScenarioTransitRecheckResult({
    required this.status,
    this.candidate,
    this.differences = const <ScenarioTransitSnapshotDiff>[],
  });

  final ScenarioTransitRecheckStatus status;
  final ScenarioTransitServiceOption? candidate;
  final List<ScenarioTransitSnapshotDiff> differences;

  bool get canReplace =>
      status == ScenarioTransitRecheckStatus.changed && candidate != null;
}

ScenarioScheduleSnapshotDraft? officialTransitSnapshot(ScenarioItemDraft item) {
  final source = item.source;
  if (item.kind != ScenarioItemKind.plannedTransport ||
      source is! ScenarioPlannedTransportSourceDraft) {
    return null;
  }
  final snapshot = source.scheduleSnapshot;
  if (snapshot == null || snapshot.providerCode == 'manual') return null;
  return snapshot;
}
