import '../../../../core/id/id_generator.dart';
import '../entities/scenario_budget_draft.dart';
import '../entities/scenario_draft_data.dart';
import '../entities/scenario_item_draft.dart';
import '../entities/scenario_transit_mutation.dart';
import '../entities/scenario_transit_schedule.dart';
import 'build_scenario_transit_snapshot_usecase.dart';
import 'evaluate_scenario_readiness_usecase.dart';

class ApplyScenarioTransitSelectionUseCase {
  const ApplyScenarioTransitSelectionUseCase({
    required IdGenerator idGenerator,
    BuildScenarioTransitSnapshotUseCase buildSnapshot =
        const BuildScenarioTransitSnapshotUseCase(),
    EvaluateScenarioReadinessUseCase evaluateReadiness =
        const EvaluateScenarioReadinessUseCase(),
  }) : _idGenerator = idGenerator,
       _buildSnapshot = buildSnapshot,
       _evaluateReadiness = evaluateReadiness;

  final IdGenerator _idGenerator;
  final BuildScenarioTransitSnapshotUseCase _buildSnapshot;
  final EvaluateScenarioReadinessUseCase _evaluateReadiness;

  ScenarioTransitMutationResult call(ScenarioTransitMutationRequest request) {
    final draft = request.draft;
    if (draft.revision != request.expectedRevision) {
      return ScenarioTransitMutationResult.rejected(
        draft: draft,
        failure: ScenarioTransitMutationFailure.revisionConflict,
      );
    }
    if (!draft.capabilities.plannedTransport || draft.days.isEmpty) {
      return ScenarioTransitMutationResult.rejected(
        draft: draft,
        failure: ScenarioTransitMutationFailure.invalidSelection,
      );
    }
    late final ScenarioTransitSnapshotBuildResult built;
    try {
      built = _buildSnapshot(request.option);
    } on FormatException {
      return ScenarioTransitMutationResult.rejected(
        draft: draft,
        failure: ScenarioTransitMutationFailure.invalidSelection,
      );
    }
    if (!_validStopPoint(
          request.option.origin.latitude,
          request.option.origin.longitude,
        ) ||
        !_validStopPoint(
          request.option.destination.latitude,
          request.option.destination.longitude,
        )) {
      return ScenarioTransitMutationResult.rejected(
        draft: draft,
        failure: ScenarioTransitMutationFailure.invalidSelection,
      );
    }

    final targetId = request.replaceItemId?.trim();
    if (targetId == null || targetId.isEmpty) {
      return _add(draft, request, built);
    }
    return _replace(draft, request, built, targetId);
  }

  ScenarioTransitMutationResult _add(
    ScenarioDraftData draft,
    ScenarioTransitMutationRequest request,
    ScenarioTransitSnapshotBuildResult built,
  ) {
    final day = draft.days.first;
    final originId = _idGenerator.generate();
    final destinationId = _idGenerator.generate();
    final itemId = _idGenerator.generate();
    final locations = <ScenarioLocationDraft>[
      ...draft.locations,
      _location(originId, request.option.origin, draft),
      _location(destinationId, request.option.destination, draft),
    ];
    final item = ScenarioItemDraft(
      id: itemId,
      dayId: day.id,
      startLocationId: originId,
      endLocationId: destinationId,
      kind: ScenarioItemKind.plannedTransport,
      source: built.source,
      sourceStatus: ScenarioSourceStatus.ready,
      schedule: _schedule(draft, day.dayIndex, built.snapshot),
      durationMinutes: built.durationMinutes,
      cost: const ScenarioCostDraft(),
      orderLocked: false,
      timeLocked: true,
      role: ScenarioItemRole.mandatory,
      selected: true,
      publicNote: '',
    );
    return _accepted(
      draft.copyWith(
        locations: locations,
        items: <ScenarioItemDraft>[...draft.items, item],
        days: <ScenarioDayDraft>[
          _copyDay(day, itemIds: <String>[...day.itemIds, itemId]),
          ...draft.days.skip(1),
        ],
      ),
      itemId,
    );
  }

  ScenarioTransitMutationResult _replace(
    ScenarioDraftData draft,
    ScenarioTransitMutationRequest request,
    ScenarioTransitSnapshotBuildResult built,
    String targetId,
  ) {
    final index = draft.items.indexWhere((item) => item.id == targetId);
    if (index < 0) {
      return ScenarioTransitMutationResult.rejected(
        draft: draft,
        failure: ScenarioTransitMutationFailure.missingTarget,
      );
    }
    final existing = draft.items[index];
    if (officialTransitSnapshot(existing) == null) {
      return ScenarioTransitMutationResult.rejected(
        draft: draft,
        failure: ScenarioTransitMutationFailure.targetNotOfficial,
      );
    }
    ScenarioDayDraft? day;
    for (final value in draft.days) {
      if (value.id == existing.dayId) {
        day = value;
        break;
      }
    }
    if (day == null) {
      return ScenarioTransitMutationResult.rejected(
        draft: draft,
        failure: ScenarioTransitMutationFailure.invalidSelection,
      );
    }
    final originId = _replacementLocationId(
      draft,
      targetId,
      existing.startLocationId,
    );
    var destinationId = _replacementLocationId(
      draft,
      targetId,
      existing.endLocationId,
    );
    if (destinationId == originId) destinationId = _idGenerator.generate();
    final locations = _upsertLocations(draft, originId, destinationId, request);
    final replacement = ScenarioItemDraft(
      id: existing.id,
      dayId: existing.dayId,
      startLocationId: originId,
      endLocationId: destinationId,
      kind: ScenarioItemKind.plannedTransport,
      source: built.source,
      sourceStatus: ScenarioSourceStatus.ready,
      schedule: _schedule(draft, day.dayIndex, built.snapshot),
      durationMinutes: built.durationMinutes,
      cost: existing.cost,
      orderLocked: existing.orderLocked,
      timeLocked: existing.timeLocked,
      role: existing.role,
      alternativeGroupId: existing.alternativeGroupId,
      selected: existing.selected,
      publicNote: existing.publicNote,
    );
    final items = <ScenarioItemDraft>[...draft.items]..[index] = replacement;
    return _accepted(
      draft.copyWith(locations: locations, items: items),
      targetId,
    );
  }

  ScenarioTransitMutationResult _accepted(
    ScenarioDraftData candidate,
    String itemId,
  ) {
    final revised = candidate.copyWith(revision: candidate.revision + 1);
    final next = revised.copyWith(totals: _evaluateReadiness(revised).totals);
    return ScenarioTransitMutationResult.accepted(draft: next, itemId: itemId);
  }

  List<ScenarioLocationDraft> _upsertLocations(
    ScenarioDraftData draft,
    String originId,
    String destinationId,
    ScenarioTransitMutationRequest request,
  ) {
    final ids = <String>{originId, destinationId};
    return <ScenarioLocationDraft>[
      for (final location in draft.locations)
        if (!ids.contains(location.id)) location,
      _location(originId, request.option.origin, draft),
      _location(destinationId, request.option.destination, draft),
    ];
  }

  ScenarioLocationDraft _location(
    String id,
    ScenarioTransitStop stop,
    ScenarioDraftData draft,
  ) => ScenarioLocationDraft(
    id: id,
    point: ScenarioGeoPointDraft(
      latitude: stop.latitude!,
      longitude: stop.longitude!,
    ),
    title: stop.name,
    timezoneId: draft.defaultTimezoneId,
    disclosure: ScenarioLocationDisclosure.private,
  );

  ScenarioScheduleDraft _schedule(
    ScenarioDraftData draft,
    int dayIndex,
    ScenarioScheduleSnapshotDraft snapshot,
  ) {
    final start = snapshot.plannedDeparture!;
    final end = snapshot.plannedArrival!;
    final departureOffset = snapshot.departureDayOffset ?? 0;
    final arrivalOffset = snapshot.arrivalDayOffset ?? departureOffset;
    final windowEndOffset = arrivalOffset - departureOffset;
    return ScenarioScheduleDraft(
      mode: ScenarioTimeMode.window,
      planned: draft.dateMode == ScenarioDateMode.template
          ? ScenarioTemplatePlannedTimeDraft(
              startDayIndex: dayIndex + departureOffset,
              preferredStart: start,
              windowStart: start,
              windowEnd: end,
              windowEndDayOffset: windowEndOffset,
              endDayIndex: dayIndex + arrivalOffset,
              preferredEnd: end,
              startTimezoneId: draft.defaultTimezoneId,
              endTimezoneId: draft.defaultTimezoneId,
            )
          : ScenarioDatedPlannedTimeDraft(
              windowStart: start,
              windowEnd: end,
              windowEndDayOffset: windowEndOffset,
              startTimezoneId: draft.defaultTimezoneId,
              endTimezoneId: draft.defaultTimezoneId,
            ),
    );
  }

  ScenarioDayDraft _copyDay(
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

  bool _validStopPoint(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      ScenarioGeoPointDraft(latitude: latitude, longitude: longitude).isValid;

  String _replacementLocationId(
    ScenarioDraftData draft,
    String targetItemId,
    String? currentId,
  ) {
    if (currentId == null || currentId.isEmpty) return _idGenerator.generate();
    final sharedByItem = draft.items.any(
      (item) =>
          item.id != targetItemId &&
          (item.startLocationId == currentId ||
              item.endLocationId == currentId),
    );
    final sharedByDay = draft.days.any(
      (day) =>
          day.startLocationId == currentId || day.endLocationId == currentId,
    );
    final sharedByLeg = draft.legs.any(
      (leg) => leg.fromLocationId == currentId || leg.toLocationId == currentId,
    );
    return sharedByItem || sharedByDay || sharedByLeg
        ? _idGenerator.generate()
        : currentId;
  }
}
