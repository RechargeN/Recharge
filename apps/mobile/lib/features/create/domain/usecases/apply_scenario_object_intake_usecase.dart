import '../../../../core/id/id_generator.dart';
import '../entities/create_draft_entity.dart';
import '../entities/scenario_budget_draft.dart';
import '../entities/scenario_draft_data.dart';
import '../entities/scenario_item_draft.dart';
import '../entities/scenario_logistics_draft.dart';
import '../entities/scenario_object_intake.dart';
import 'evaluate_scenario_readiness_usecase.dart';

typedef ScenarioIntakeClock = DateTime Function();

class ApplyScenarioObjectIntakeUseCase {
  ApplyScenarioObjectIntakeUseCase({
    required IdGenerator idGenerator,
    EvaluateScenarioReadinessUseCase evaluateReadiness =
        const EvaluateScenarioReadinessUseCase(),
    ScenarioIntakeClock? clock,
  }) : _idGenerator = idGenerator,
       _evaluateReadiness = evaluateReadiness,
       _clock = clock ?? _utcNow;

  static const int maxBatchSize = 20;

  final IdGenerator _idGenerator;
  final EvaluateScenarioReadinessUseCase _evaluateReadiness;
  final ScenarioIntakeClock _clock;

  ScenarioIntakeResult call(ApplyScenarioObjectIntakeRequest request) {
    final intent = request.intent;
    final target = request.targetDraft;
    final scenario = target.scenarioData;

    if (intent.requesterId.trim().isEmpty) {
      return _rejected(request, ScenarioIntakeFailure.unauthenticated);
    }
    if (target.id != request.targetCreateDraftId || !_permanentId(target.id)) {
      return _rejected(request, ScenarioIntakeFailure.targetNotFound);
    }
    if (target.objectType != CreateObjectType.scenario || scenario == null) {
      return _rejected(request, ScenarioIntakeFailure.targetNotScenario);
    }
    if (target.organizerId != intent.requesterId) {
      return _rejected(request, ScenarioIntakeFailure.accessDenied);
    }
    if (_unavailableTarget(target)) {
      return _rejected(request, ScenarioIntakeFailure.targetUnavailable);
    }

    final replayedRevision = request.replayedTargetRevision;
    if (replayedRevision != null) {
      if (scenario.revision != replayedRevision) {
        return _rejected(
          request,
          ScenarioIntakeFailure.revisionConflict,
          currentRevision: scenario.revision,
        );
      }
      return ScenarioIntakeApplied(
        draft: target,
        targetCreateDraftId: target.id,
        targetRevision: replayedRevision,
        createdItemIds: const <String>[],
        createdLocationIds: const <String>[],
        replayedIdempotentSuccess: true,
      );
    }

    if (scenario.revision != request.expectedScenarioRevision) {
      return _rejected(
        request,
        ScenarioIntakeFailure.revisionConflict,
        currentRevision: scenario.revision,
      );
    }
    if (intent.contractVersion !=
            ScenarioObjectIntakeIntent.currentContractVersion ||
        !_permanentId(intent.intentId)) {
      return _rejected(request, ScenarioIntakeFailure.invalidCandidate);
    }
    if (intent.candidates.isEmpty ||
        intent.candidates.length > maxBatchSize ||
        request.placement.orderedRefs.isEmpty ||
        request.placement.orderedRefs.length > maxBatchSize) {
      return _rejected(request, ScenarioIntakeFailure.batchLimitExceeded);
    }

    final candidateByRef = <ScenarioObjectRef, ScenarioIntakeCandidate>{};
    for (final candidate in intent.candidates) {
      if (candidateByRef.containsKey(candidate.ref)) {
        return _rejected(request, ScenarioIntakeFailure.invalidCandidate);
      }
      candidateByRef[candidate.ref] = candidate;
    }
    final orderedRefs = request.placement.orderedRefs;
    final orderedRefSet = orderedRefs.toSet();
    if (orderedRefSet.length != orderedRefs.length ||
        orderedRefs.length != candidateByRef.length ||
        orderedRefs.any((ref) => !candidateByRef.containsKey(ref)) ||
        request.placement.roles.keys.toSet().length != orderedRefSet.length ||
        !request.placement.roles.keys.every(orderedRefSet.contains) ||
        !request.placement.confirmedDuplicates.every(orderedRefSet.contains) ||
        !request.placement.confirmedUnavailable.every(orderedRefSet.contains) ||
        !request.placement.confirmedScheduleAdjustments.every(
          orderedRefSet.contains,
        )) {
      return _rejected(request, ScenarioIntakeFailure.invalidCandidate);
    }

    for (final ref in orderedRefs) {
      final candidate = candidateByRef[ref]!;
      final failure = _validateCandidate(candidate, request.placement);
      if (failure != null) return _rejected(request, failure);
      final role = request.placement.roles[ref];
      if (role != ScenarioItemRole.mandatory &&
          role != ScenarioItemRole.optional) {
        return _rejected(request, ScenarioIntakeFailure.invalidCandidate);
      }
      if (_scheduleNeedsAdjustment(candidate.schedule, scenario.dateMode) &&
          !request.placement.confirmedScheduleAdjustments.contains(ref)) {
        return _rejected(
          request,
          ScenarioIntakeFailure.scheduleConfirmationRequired,
        );
      }
    }

    final placement = _resolvePlacement(scenario, request.placement);
    if (placement == null) {
      return _rejected(request, ScenarioIntakeFailure.invalidPlacement);
    }
    final affectedLegs = _affectedBoundaryLegs(scenario, placement);
    if (affectedLegs.any((leg) => leg.lockedByUser)) {
      return _rejected(request, ScenarioIntakeFailure.lockedLegBoundary);
    }

    final createdItemIds = <String>[];
    final createdLocationIds = <String>[];
    final newItems = <ScenarioItemDraft>[];
    final newLocations = <ScenarioLocationDraft>[];
    final allocatedIds = <String>{
      ...scenario.items.map((item) => item.id),
      ...scenario.locations.map((location) => location.id),
    };
    for (final ref in orderedRefs) {
      final candidate = candidateByRef[ref]!;
      final itemId = _nextPermanentUniqueId(allocatedIds);
      if (itemId == null) {
        return _rejected(request, ScenarioIntakeFailure.invalidCandidate);
      }
      createdItemIds.add(itemId);
      String? locationId;
      final locationSnapshot = candidate.location;
      if (locationSnapshot != null) {
        locationId = _nextPermanentUniqueId(allocatedIds);
        if (locationId == null) {
          return _rejected(request, ScenarioIntakeFailure.invalidCandidate);
        }
        createdLocationIds.add(locationId);
        newLocations.add(
          ScenarioLocationDraft(
            id: locationId,
            point: locationSnapshot.point,
            title: locationSnapshot.title.trim(),
            address: _trimmedOrNull(locationSnapshot.address),
            marketId: _trimmedOrNull(locationSnapshot.marketId),
            regionId: _trimmedOrNull(locationSnapshot.regionId),
            timezoneId:
                _trimmedOrNull(locationSnapshot.timezoneId) ??
                scenario.defaultTimezoneId,
            disclosure: locationSnapshot.disclosure,
            sourceObjectId: ref.objectId,
            sourceObjectType: ref.objectType,
          ),
        );
      }
      final role = request.placement.roles[ref]!;
      newItems.add(
        ScenarioItemDraft(
          id: itemId,
          dayId: placement.day?.id,
          startLocationId: locationId,
          endLocationId: locationId,
          kind: _kind(ref.objectType),
          source: ScenarioCatalogObjectSourceDraft(
            objectId: ref.objectId,
            objectType: ref.objectType,
            snapshot: candidate.snapshot,
          ),
          sourceStatus: candidate.sourceStatus,
          schedule:
              _compatibleSchedule(candidate.schedule, scenario.dateMode) ??
              _defaultSchedule(scenario, placement.day?.dayIndex ?? 0),
          durationMinutes: candidate.snapshot.durationMinutes,
          cost: const ScenarioCostDraft(),
          orderLocked: false,
          timeLocked: false,
          role: role,
          selected: true,
          publicNote: '',
        ),
      );
    }

    final nextDays = placement.day == null
        ? scenario.days
        : scenario.days
              .map(
                (day) => day.id == placement.day!.id
                    ? _copyDay(
                        day,
                        itemIds: <String>[
                          ...day.itemIds.take(placement.insertionIndex),
                          ...createdItemIds,
                          ...day.itemIds.skip(placement.insertionIndex),
                        ],
                      )
                    : day,
              )
              .toList(growable: false);
    final candidateDraft = scenario.copyWith(
      revision: scenario.revision + 1,
      days: nextDays,
      locations: <ScenarioLocationDraft>[
        ...scenario.locations,
        ...newLocations,
      ],
      items: <ScenarioItemDraft>[...scenario.items, ...newItems],
      unscheduledItemIds: placement.day == null
          ? <String>[...scenario.unscheduledItemIds, ...createdItemIds]
          : scenario.unscheduledItemIds,
      legs: scenario.legs
          .where((leg) => !affectedLegs.contains(leg))
          .toList(growable: false),
    );
    final revised = candidateDraft.copyWith(
      totals: _evaluateReadiness(candidateDraft).totals,
    );
    final acceptedDraft = target.copyWith(
      scenarioData: revised,
      updatedAtUtc: _clock().toUtc(),
    );
    return ScenarioIntakeApplied(
      draft: acceptedDraft,
      targetCreateDraftId: target.id,
      targetRevision: revised.revision,
      createdItemIds: List<String>.unmodifiable(createdItemIds),
      createdLocationIds: List<String>.unmodifiable(createdLocationIds),
      replayedIdempotentSuccess: false,
    );
  }

  ScenarioIntakeFailure? _validateCandidate(
    ScenarioIntakeCandidate candidate,
    ScenarioIntakePlacement placement,
  ) {
    if (!_permanentId(candidate.ref.objectId) ||
        (candidate.sourceRevision != null && candidate.sourceRevision! < 0)) {
      return ScenarioIntakeFailure.invalidCandidate;
    }
    final snapshot = candidate.snapshot;
    if (snapshot.title.trim().isEmpty) {
      return ScenarioIntakeFailure.incompleteSnapshot;
    }
    if ((snapshot.durationMinutes != null && snapshot.durationMinutes! <= 0) ||
        (snapshot.distanceM != null &&
            (!snapshot.distanceM!.isFinite || snapshot.distanceM! < 0))) {
      return ScenarioIntakeFailure.invalidCandidate;
    }
    if (candidate.sourceStatus == ScenarioSourceStatus.unresolved) {
      return ScenarioIntakeFailure.incompleteSnapshot;
    }
    if (candidate.sourceStatus == ScenarioSourceStatus.unavailable &&
        !placement.confirmedUnavailable.contains(candidate.ref)) {
      return ScenarioIntakeFailure.invalidCandidate;
    }
    final location = candidate.location;
    if (location != null &&
        (location.title.trim().isEmpty || !location.point.isValid)) {
      return ScenarioIntakeFailure.invalidCandidate;
    }
    return null;
  }

  _ResolvedPlacement? _resolvePlacement(
    ScenarioDraftData scenario,
    ScenarioIntakePlacement placement,
  ) {
    final dayId = _trimmedOrNull(placement.dayId);
    final anchorId = _trimmedOrNull(placement.afterItemId);
    if (dayId == null) {
      return anchorId == null
          ? const _ResolvedPlacement(day: null, insertionIndex: 0)
          : null;
    }
    ScenarioDayDraft? targetDay;
    for (final day in scenario.days) {
      if (day.id == dayId) targetDay = day;
    }
    if (targetDay == null) return null;
    if (anchorId == null) {
      return _ResolvedPlacement(
        day: targetDay,
        insertionIndex: targetDay.itemIds.length,
      );
    }
    final anchorIndex = targetDay.itemIds.indexOf(anchorId);
    if (anchorIndex < 0) return null;
    return _ResolvedPlacement(day: targetDay, insertionIndex: anchorIndex + 1);
  }

  List<ScenarioLegDraft> _affectedBoundaryLegs(
    ScenarioDraftData scenario,
    _ResolvedPlacement placement,
  ) {
    final day = placement.day;
    if (day == null) return const <ScenarioLegDraft>[];
    final previousId = placement.insertionIndex == 0
        ? null
        : day.itemIds[placement.insertionIndex - 1];
    final nextId = placement.insertionIndex == day.itemIds.length
        ? null
        : day.itemIds[placement.insertionIndex];
    return scenario.legs
        .where(
          (leg) =>
              leg.dayId == day.id &&
              leg.fromItemId == previousId &&
              leg.toItemId == nextId,
        )
        .toList(growable: false);
  }

  String? _nextPermanentUniqueId(Set<String> allocated) {
    final id = _idGenerator.generate().trim();
    if (!_permanentId(id) || !allocated.add(id)) return null;
    return id;
  }

  ScenarioIntakeRejected _rejected(
    ApplyScenarioObjectIntakeRequest request,
    ScenarioIntakeFailure failure, {
    int? currentRevision,
  }) => ScenarioIntakeRejected(
    failure: failure,
    retainedIntent: request.intent,
    originalDraft: request.targetDraft,
    currentTargetRevision:
        currentRevision ?? request.targetDraft.scenarioData?.revision,
  );

  static bool _unavailableTarget(CreateDraftEntity target) =>
      target.draftStatus != DraftStatus.draft ||
      target.publishStatus != PublishStatus.draft;

  static bool _permanentId(String value) {
    final id = value.trim();
    return id == value &&
        id.isNotEmpty &&
        id.runes.length <= 256 &&
        !id.startsWith('loc_');
  }

  static ScenarioItemKind _kind(ScenarioCatalogObjectType type) =>
      switch (type) {
        ScenarioCatalogObjectType.event => ScenarioItemKind.event,
        ScenarioCatalogObjectType.place => ScenarioItemKind.visit,
        ScenarioCatalogObjectType.activity => ScenarioItemKind.activity,
        ScenarioCatalogObjectType.route => ScenarioItemKind.route,
        ScenarioCatalogObjectType.bookableSession =>
          ScenarioItemKind.bookableSession,
      };

  static ScenarioScheduleDraft _defaultSchedule(
    ScenarioDraftData draft,
    int dayIndex,
  ) => ScenarioScheduleDraft(
    mode: ScenarioTimeMode.flexible,
    planned: draft.dateMode == ScenarioDateMode.template
        ? ScenarioTemplatePlannedTimeDraft(startDayIndex: dayIndex)
        : const ScenarioDatedPlannedTimeDraft(),
  );

  static bool _scheduleNeedsAdjustment(
    ScenarioScheduleDraft? schedule,
    ScenarioDateMode dateMode,
  ) => schedule != null && _compatibleSchedule(schedule, dateMode) == null;

  static ScenarioScheduleDraft? _compatibleSchedule(
    ScenarioScheduleDraft? schedule,
    ScenarioDateMode dateMode,
  ) {
    if (schedule == null) return null;
    final planned = schedule.planned;
    final matches = switch (dateMode) {
      ScenarioDateMode.template => planned is ScenarioTemplatePlannedTimeDraft,
      ScenarioDateMode.dated => planned is ScenarioDatedPlannedTimeDraft,
    };
    return matches ? schedule : null;
  }

  static ScenarioDayDraft _copyDay(
    ScenarioDayDraft day, {
    required List<String> itemIds,
  }) => ScenarioDayDraft(
    id: day.id,
    title: day.title,
    dayIndex: day.dayIndex,
    timezoneId: day.timezoneId,
    localDate: day.localDate,
    startLocationId: day.startLocationId,
    endLocationId: day.endLocationId,
    preferredStartTime: day.preferredStartTime,
    preferredEndTime: day.preferredEndTime,
    itemIds: itemIds,
  );

  static String? _trimmedOrNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}

class _ResolvedPlacement {
  const _ResolvedPlacement({required this.day, required this.insertionIndex});

  final ScenarioDayDraft? day;
  final int insertionIndex;
}
