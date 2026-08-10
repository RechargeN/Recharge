import 'create_draft_entity.dart';
import 'scenario_item_draft.dart';

enum ScenarioIntakeSourceSurface { details, search, map }

class ScenarioObjectRef {
  const ScenarioObjectRef({required this.objectId, required this.objectType});

  final String objectId;
  final ScenarioCatalogObjectType objectType;

  String get stableKey => '${objectType.name}:$objectId';

  @override
  bool operator ==(Object other) =>
      other is ScenarioObjectRef &&
      other.objectId == objectId &&
      other.objectType == objectType;

  @override
  int get hashCode => Object.hash(objectId, objectType);
}

class ScenarioIntakeLocationSnapshot {
  const ScenarioIntakeLocationSnapshot({
    required this.title,
    required this.point,
    this.address,
    this.marketId,
    this.regionId,
    this.timezoneId,
    this.disclosure = ScenarioLocationDisclosure.private,
  });

  final String title;
  final ScenarioGeoPointDraft point;
  final String? address;
  final String? marketId;
  final String? regionId;
  final String? timezoneId;
  final ScenarioLocationDisclosure disclosure;
}

class ScenarioIntakeCandidate {
  const ScenarioIntakeCandidate({
    required this.ref,
    required this.snapshot,
    required this.sourceStatus,
    this.sourceRevision,
    this.location,
    this.schedule,
  });

  final ScenarioObjectRef ref;
  final int? sourceRevision;
  final ScenarioObjectSnapshotDraft snapshot;
  final ScenarioSourceStatus sourceStatus;
  final ScenarioIntakeLocationSnapshot? location;
  final ScenarioScheduleDraft? schedule;
}

class ScenarioObjectIntakeIntent {
  ScenarioObjectIntakeIntent({
    required this.contractVersion,
    required this.intentId,
    required this.requesterId,
    required this.sourceSurface,
    required List<ScenarioIntakeCandidate> candidates,
  }) : candidates = List<ScenarioIntakeCandidate>.unmodifiable(candidates);

  static const int currentContractVersion = 1;

  final int contractVersion;
  final String intentId;
  final String requesterId;
  final ScenarioIntakeSourceSurface sourceSurface;
  final List<ScenarioIntakeCandidate> candidates;
}

class ScenarioIntakePlacement {
  ScenarioIntakePlacement({
    required List<ScenarioObjectRef> orderedRefs,
    required Map<ScenarioObjectRef, ScenarioItemRole> roles,
    this.dayId,
    this.afterItemId,
    Set<ScenarioObjectRef> confirmedDuplicates = const <ScenarioObjectRef>{},
    Set<ScenarioObjectRef> confirmedUnavailable = const <ScenarioObjectRef>{},
    Set<ScenarioObjectRef> confirmedScheduleAdjustments =
        const <ScenarioObjectRef>{},
  }) : orderedRefs = List<ScenarioObjectRef>.unmodifiable(orderedRefs),
       roles = Map<ScenarioObjectRef, ScenarioItemRole>.unmodifiable(roles),
       confirmedDuplicates = Set<ScenarioObjectRef>.unmodifiable(
         confirmedDuplicates,
       ),
       confirmedUnavailable = Set<ScenarioObjectRef>.unmodifiable(
         confirmedUnavailable,
       ),
       confirmedScheduleAdjustments = Set<ScenarioObjectRef>.unmodifiable(
         confirmedScheduleAdjustments,
       );

  /// Null means that all objects are added to Unscheduled.
  final String? dayId;
  final String? afterItemId;
  final List<ScenarioObjectRef> orderedRefs;
  final Map<ScenarioObjectRef, ScenarioItemRole> roles;
  final Set<ScenarioObjectRef> confirmedDuplicates;
  final Set<ScenarioObjectRef> confirmedUnavailable;
  final Set<ScenarioObjectRef> confirmedScheduleAdjustments;
}

class ApplyScenarioObjectIntakeRequest {
  ApplyScenarioObjectIntakeRequest({
    required this.intent,
    required this.targetDraft,
    required this.targetCreateDraftId,
    required this.expectedScenarioRevision,
    required this.placement,
    this.replayedTargetRevision,
  });

  final ScenarioObjectIntakeIntent intent;
  final CreateDraftEntity targetDraft;
  final String targetCreateDraftId;
  final int expectedScenarioRevision;
  final ScenarioIntakePlacement placement;

  /// Supplied by the persistence boundary when this intent was already saved.
  final int? replayedTargetRevision;
}

enum ScenarioIntakeFailure {
  unauthenticated,
  accessDenied,
  targetNotFound,
  targetNotScenario,
  targetUnavailable,
  revisionConflict,
  intentExpired,
  intentAlreadyConsumed,
  invalidCandidate,
  unsupportedObjectType,
  incompleteSnapshot,
  batchLimitExceeded,
  duplicateConfirmationRequired,
  scheduleConfirmationRequired,
  invalidPlacement,
  lockedLegBoundary,
  persistenceUnavailable,
}

sealed class ScenarioIntakeResult {
  const ScenarioIntakeResult();
}

class ScenarioIntakeApplied extends ScenarioIntakeResult {
  const ScenarioIntakeApplied({
    required this.draft,
    required this.targetCreateDraftId,
    required this.targetRevision,
    required this.createdItemIds,
    required this.createdLocationIds,
    required this.replayedIdempotentSuccess,
  });

  final CreateDraftEntity draft;
  final String targetCreateDraftId;
  final int targetRevision;
  final List<String> createdItemIds;
  final List<String> createdLocationIds;
  final bool replayedIdempotentSuccess;
}

class ScenarioIntakeRejected extends ScenarioIntakeResult {
  const ScenarioIntakeRejected({
    required this.failure,
    required this.retainedIntent,
    required this.originalDraft,
    this.currentTargetRevision,
  });

  final ScenarioIntakeFailure failure;
  final ScenarioObjectIntakeIntent retainedIntent;

  /// The exact input instance. Rejection never exposes a partially changed copy.
  final CreateDraftEntity originalDraft;
  final int? currentTargetRevision;
}
