import '../../../core/id/id_generator.dart';
import '../domain/entities/scenario_budget_draft.dart';
import '../domain/entities/scenario_draft_data.dart';
import '../domain/entities/scenario_item_draft.dart';
import '../domain/entities/scenario_logistics_draft.dart';
import '../domain/entities/scenario_object_intake.dart';
import '../domain/entities/scenario_transit_mutation.dart';
import '../domain/entities/scenario_transit_schedule.dart';
import '../domain/repositories/catalog_object_picker_port.dart';
import '../domain/usecases/evaluate_scenario_readiness_usecase.dart';
import '../domain/usecases/apply_scenario_transit_selection_usecase.dart';
import '../domain/usecases/apply_scenario_object_intake_usecase.dart';

class ScenarioCreateCoordinator {
  ScenarioCreateCoordinator({
    required IdGenerator idGenerator,
    EvaluateScenarioReadinessUseCase evaluateReadiness =
        const EvaluateScenarioReadinessUseCase(),
    ApplyScenarioTransitSelectionUseCase? applyTransitSelection,
    ApplyScenarioObjectIntakeUseCase? applyObjectIntake,
  }) : _idGenerator = idGenerator,
       _evaluateReadiness = evaluateReadiness,
       _applyTransitSelection =
           applyTransitSelection ??
           ApplyScenarioTransitSelectionUseCase(
             idGenerator: idGenerator,
             evaluateReadiness: evaluateReadiness,
           ),
       _applyObjectIntake =
           applyObjectIntake ??
           ApplyScenarioObjectIntakeUseCase(
             idGenerator: idGenerator,
             evaluateReadiness: evaluateReadiness,
           );

  final IdGenerator _idGenerator;
  final EvaluateScenarioReadinessUseCase _evaluateReadiness;
  final ApplyScenarioTransitSelectionUseCase _applyTransitSelection;
  final ApplyScenarioObjectIntakeUseCase _applyObjectIntake;

  ScenarioIntakeResult applyObjectIntake(
    ApplyScenarioObjectIntakeRequest request,
  ) => _applyObjectIntake(request);

  ScenarioTransitMutationResult applyTransitSelection(
    ScenarioDraftData draft, {
    required int expectedRevision,
    required ScenarioTransitServiceOption option,
    String? replaceItemId,
  }) => _applyTransitSelection(
    ScenarioTransitMutationRequest(
      draft: draft,
      expectedRevision: expectedRevision,
      option: option,
      replaceItemId: replaceItemId,
    ),
  );

  ScenarioDraftData initial({
    required String timezoneId,
    required String currencyCode,
  }) {
    final String dayId = _idGenerator.generate();
    return ScenarioDraftData.defaults(
      timezoneId: timezoneId,
      currencyCode: currencyCode,
    ).copyWith(
      days: <ScenarioDayDraft>[
        ScenarioDayDraft(
          id: dayId,
          title: 'Day 1',
          dayIndex: 0,
          timezoneId: timezoneId,
          itemIds: const <String>[],
        ),
      ],
      capabilities: const ScenarioCapabilitiesDraft(plannedTransport: true),
    );
  }

  ScenarioDraftData updateContext(
    ScenarioDraftData draft, {
    ScenarioFormat? format,
    ScenarioDateMode? dateMode,
    int? peopleCount,
    ScenarioPartyKind? partyKind,
    ScenarioPace? pace,
    ScenarioBudgetBasis? budgetBasis,
  }) {
    final ScenarioFormat nextFormat = format ?? draft.format;
    final ScenarioDateMode nextDateMode = dateMode ?? draft.dateMode;
    final bool multiDay =
        nextFormat == ScenarioFormat.weekend ||
        nextFormat == ScenarioFormat.trip;
    final bool dateModeChanged = nextDateMode != draft.dateMode;
    final DateTime firstDate = DateTime.now().toUtc().add(
      const Duration(days: 1),
    );
    final Map<String, int> dayIndexById = <String, int>{
      for (final ScenarioDayDraft day in draft.days) day.id: day.dayIndex,
    };
    return _next(
      draft.copyWith(
        format: nextFormat,
        dateMode: nextDateMode,
        days: dateModeChanged
            ? draft.days
                  .map((ScenarioDayDraft day) {
                    final DateTime localDate = firstDate.add(
                      Duration(days: day.dayIndex),
                    );
                    return ScenarioDayDraft(
                      id: day.id,
                      title: day.title,
                      dayIndex: day.dayIndex,
                      timezoneId: day.timezoneId ?? draft.defaultTimezoneId,
                      localDate: nextDateMode == ScenarioDateMode.dated
                          ? ScenarioLocalDateDraft(
                              year: localDate.year,
                              month: localDate.month,
                              day: localDate.day,
                            )
                          : null,
                      startLocationId: day.startLocationId,
                      endLocationId: day.endLocationId,
                      preferredStartTime: day.preferredStartTime,
                      preferredEndTime: day.preferredEndTime,
                      itemIds: day.itemIds,
                    );
                  })
                  .toList(growable: false)
            : draft.days,
        items: dateModeChanged
            ? draft.items
                  .map((ScenarioItemDraft item) {
                    final int dayIndex = item.dayId == null
                        ? 0
                        : (dayIndexById[item.dayId!] ?? 0);
                    return _copyItem(
                      item,
                      schedule: ScenarioScheduleDraft(
                        mode: ScenarioTimeMode.flexible,
                        planned: nextDateMode == ScenarioDateMode.template
                            ? ScenarioTemplatePlannedTimeDraft(
                                startDayIndex: dayIndex,
                              )
                            : const ScenarioDatedPlannedTimeDraft(),
                      ),
                    );
                  })
                  .toList(growable: false)
            : draft.items,
        party: ScenarioPartyDraft(
          peopleCount: peopleCount ?? draft.party.peopleCount,
          kind: partyKind ?? draft.party.kind,
          childrenCount: draft.party.childrenCount,
        ),
        constraints: ScenarioConstraintsDraft(
          totalBudgetLimit: draft.constraints.totalBudgetLimit,
          budgetBasis: budgetBasis ?? draft.constraints.budgetBasis,
          primaryTravelMode: draft.constraints.primaryTravelMode,
          allowedTravelModes: draft.constraints.allowedTravelModes,
          vehicleProfile: draft.constraints.vehicleProfile,
          maxWalkingMinutesPerLeg: draft.constraints.maxWalkingMinutesPerLeg,
          maxTravelMinutesPerDay: draft.constraints.maxTravelMinutesPerDay,
          pace: pace ?? draft.constraints.pace,
          interestCategoryIds: draft.constraints.interestCategoryIds,
          accessibilityRequirementIds:
              draft.constraints.accessibilityRequirementIds,
          freeExperienceItemsOnly: draft.constraints.freeExperienceItemsOnly,
        ),
        capabilities: ScenarioCapabilitiesDraft(
          multiDay: multiDay,
          stay: draft.capabilities.stay,
          plannedTransport: draft.capabilities.plannedTransport,
          alternatives: draft.capabilities.alternatives,
          multiCurrency: draft.capabilities.multiCurrency,
          optimizer: draft.capabilities.optimizer,
          unlistedShare: draft.capabilities.unlistedShare,
          publicPublish: false,
          liveLogistics: false,
        ),
      ),
    );
  }

  ScenarioDraftData updateTransportPreferences(
    ScenarioDraftData draft, {
    required ScenarioTravelMode primaryTravelMode,
    required Set<ScenarioTravelMode> allowedTravelModes,
  }) {
    final Set<ScenarioTravelMode> normalizedModes = <ScenarioTravelMode>{
      ...allowedTravelModes,
      primaryTravelMode,
    };
    final ScenarioVehicleProfileDraft currentVehicle =
        draft.constraints.vehicleProfile;
    final ScenarioVehicleProfileDraft normalizedVehicle =
        ScenarioVehicleProfileDraft(
          enabled: normalizedModes.contains(ScenarioTravelMode.car),
          label: currentVehicle.label,
          passengerSeats: currentVehicle.passengerSeats,
        );
    return _next(
      draft.copyWith(
        constraints: ScenarioConstraintsDraft(
          totalBudgetLimit: draft.constraints.totalBudgetLimit,
          budgetBasis: draft.constraints.budgetBasis,
          primaryTravelMode: primaryTravelMode,
          allowedTravelModes: normalizedModes,
          vehicleProfile: normalizedVehicle,
          maxWalkingMinutesPerLeg: draft.constraints.maxWalkingMinutesPerLeg,
          maxTravelMinutesPerDay: draft.constraints.maxTravelMinutesPerDay,
          pace: draft.constraints.pace,
          interestCategoryIds: draft.constraints.interestCategoryIds,
          accessibilityRequirementIds:
              draft.constraints.accessibilityRequirementIds,
          freeExperienceItemsOnly: draft.constraints.freeExperienceItemsOnly,
        ),
      ),
    );
  }

  ScenarioDraftData addCatalogItem(
    ScenarioDraftData draft,
    ScenarioCatalogObjectCandidate candidate,
  ) {
    final String itemId = _idGenerator.generate();
    final ScenarioItemKind kind = switch (candidate.objectType) {
      ScenarioCatalogObjectType.event => ScenarioItemKind.event,
      ScenarioCatalogObjectType.place => ScenarioItemKind.visit,
      ScenarioCatalogObjectType.activity => ScenarioItemKind.activity,
      ScenarioCatalogObjectType.route => ScenarioItemKind.route,
      ScenarioCatalogObjectType.bookableSession =>
        ScenarioItemKind.bookableSession,
    };
    return _appendItem(
      draft,
      ScenarioItemDraft(
        id: itemId,
        dayId: draft.days.first.id,
        kind: kind,
        source: ScenarioCatalogObjectSourceDraft(
          objectId: candidate.id,
          objectType: candidate.objectType,
          snapshot: ScenarioObjectSnapshotDraft(
            title: candidate.title,
            coverMediaId: candidate.coverMediaId,
            publisherId: candidate.publisherId,
            durationMinutes: candidate.durationMinutes,
            checkedAtUtc: DateTime.now().toUtc(),
          ),
        ),
        sourceStatus: ScenarioSourceStatus.ready,
        schedule: _scheduleFor(draft),
        durationMinutes: candidate.durationMinutes,
        cost: const ScenarioCostDraft(),
        orderLocked: false,
        timeLocked: false,
        role: ScenarioItemRole.mandatory,
        selected: true,
        publicNote: '',
      ),
    );
  }

  ScenarioDraftData addTimeBlock(
    ScenarioDraftData draft, {
    required String title,
    required int durationMinutes,
  }) {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty || durationMinutes <= 0) return draft;
    return _appendItem(
      draft,
      ScenarioItemDraft(
        id: _idGenerator.generate(),
        dayId: draft.days.first.id,
        kind: ScenarioItemKind.timeBlock,
        source: ScenarioTimeBlockSourceDraft(title: normalizedTitle),
        sourceStatus: ScenarioSourceStatus.ready,
        schedule: _scheduleFor(draft),
        durationMinutes: durationMinutes,
        cost: const ScenarioCostDraft(),
        orderLocked: false,
        timeLocked: false,
        role: ScenarioItemRole.mandatory,
        selected: true,
        publicNote: '',
      ),
    );
  }

  ScenarioDraftData addPlannedTransport(
    ScenarioDraftData draft, {
    required ScenarioPlannedTransportKind kind,
    required String carrierName,
    required String serviceLabel,
    required int durationMinutes,
    ScenarioLocalTimeDraft? plannedDeparture,
    ScenarioLocalTimeDraft? plannedArrival,
  }) {
    final String normalizedCarrier = carrierName.trim();
    final String normalizedService = serviceLabel.trim();
    if (normalizedService.isEmpty || durationMinutes <= 0) {
      return draft;
    }
    final ScenarioLocalDateDraft? serviceDate =
        draft.dateMode == ScenarioDateMode.dated
        ? draft.days.first.localDate
        : null;
    final ScenarioScheduleSnapshotDraft snapshot =
        ScenarioScheduleSnapshotDraft(
          freshness: serviceDate == null
              ? ScenarioScheduleFreshness.unknown
              : ScenarioScheduleFreshness.current,
          providerCode: 'manual',
          serviceDate: serviceDate,
          retrievedAtUtc: DateTime.now().toUtc(),
          carrierName: normalizedCarrier.isEmpty ? null : normalizedCarrier,
          serviceLabel: normalizedService,
          plannedDeparture: plannedDeparture,
          plannedArrival: plannedArrival,
        );
    return _appendItem(
      draft,
      ScenarioItemDraft(
        id: _idGenerator.generate(),
        dayId: draft.days.first.id,
        kind: ScenarioItemKind.plannedTransport,
        source: ScenarioPlannedTransportSourceDraft(
          kind: kind,
          carrierName: normalizedCarrier.isEmpty ? null : normalizedCarrier,
          publicServiceLabel: normalizedService,
          scheduleSnapshot: snapshot,
        ),
        sourceStatus: ScenarioSourceStatus.ready,
        schedule: _scheduleFor(draft),
        durationMinutes: durationMinutes,
        cost: const ScenarioCostDraft(),
        orderLocked: false,
        timeLocked: plannedDeparture != null,
        role: ScenarioItemRole.mandatory,
        selected: true,
        publicNote: '',
      ),
    );
  }

  ScenarioDraftData upsertManualLeg(
    ScenarioDraftData draft, {
    required String fromItemId,
    required String toItemId,
    required ScenarioTravelMode mode,
    required int durationMinutes,
    required double distanceKm,
    int? otherCostMinorUnits,
  }) {
    if (durationMinutes <= 0 || distanceKm < 0) {
      return draft;
    }
    final ScenarioItemDraft? from = _itemById(draft, fromItemId);
    final ScenarioItemDraft? to = _itemById(draft, toItemId);
    final String? fromLocationId = from?.endLocationId ?? from?.startLocationId;
    final String? toLocationId = to?.startLocationId ?? to?.endLocationId;
    if (from == null ||
        to == null ||
        from.dayId == null ||
        from.dayId != to.dayId ||
        fromLocationId == null ||
        toLocationId == null) {
      return draft;
    }
    final double distanceM = distanceKm * 1000;
    final List<ScenarioMoneyEstimateDraft> costs =
        <ScenarioMoneyEstimateDraft>[];
    if (otherCostMinorUnits != null && otherCostMinorUnits >= 0) {
      costs.add(
        ScenarioMoneyEstimateDraft(
          componentCode: 'travel_extra',
          knowledge: ScenarioPriceKnowledge.known,
          source: ScenarioPriceSource.manual,
          amount: ScenarioMoneyDraft(
            minorUnits: otherCostMinorUnits,
            currencyCode: draft.displayCurrencyCode,
          ),
          basis: ScenarioPriceBasis.perGroup,
          observedAtUtc: DateTime.now().toUtc(),
        ),
      );
    }
    final ScenarioLegDraft leg = ScenarioLegDraft(
      id:
          _existingLegId(draft, fromItemId, toItemId) ??
          _idGenerator.generate(),
      dayId: from.dayId!,
      fromItemId: fromItemId,
      toItemId: toItemId,
      fromLocationId: fromLocationId,
      toLocationId: toLocationId,
      mode: mode,
      source: ScenarioLegSource.manual,
      status: ScenarioLegStatus.ready,
      distanceM: distanceM,
      durationMinutes: durationMinutes,
      cost: ScenarioCostDraft(components: costs),
      warningCode: 'manual_value',
      updatedAtUtc: DateTime.now().toUtc(),
      lockedByUser: true,
    );
    return _next(
      draft.copyWith(
        legs: <ScenarioLegDraft>[
          for (final ScenarioLegDraft current in draft.legs)
            if (!(current.fromItemId == fromItemId &&
                current.toItemId == toItemId))
              current,
          leg,
        ],
      ),
    );
  }

  ScenarioDraftData addCustomStop(
    ScenarioDraftData draft, {
    required String title,
    required int durationMinutes,
    required double latitude,
    required double longitude,
  }) {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty ||
        durationMinutes <= 0 ||
        !ScenarioGeoPointDraft(
          latitude: latitude,
          longitude: longitude,
        ).isValid) {
      return draft;
    }
    final String locationId = _idGenerator.generate();
    final ScenarioLocationDraft location = ScenarioLocationDraft(
      id: locationId,
      point: ScenarioGeoPointDraft(latitude: latitude, longitude: longitude),
      title: normalizedTitle,
      timezoneId: draft.defaultTimezoneId,
      disclosure: ScenarioLocationDisclosure.private,
    );
    final ScenarioItemDraft item = ScenarioItemDraft(
      id: _idGenerator.generate(),
      dayId: draft.days.first.id,
      startLocationId: locationId,
      endLocationId: locationId,
      kind: ScenarioItemKind.visit,
      source: ScenarioCustomLocationSourceDraft(locationId: locationId),
      sourceStatus: ScenarioSourceStatus.ready,
      schedule: _scheduleFor(draft),
      durationMinutes: durationMinutes,
      cost: const ScenarioCostDraft(),
      orderLocked: false,
      timeLocked: false,
      role: ScenarioItemRole.mandatory,
      selected: true,
      publicNote: '',
    );
    final ScenarioDraftData withLocation = draft.copyWith(
      locations: <ScenarioLocationDraft>[...draft.locations, location],
    );
    return _appendItem(withLocation, item);
  }

  ScenarioDraftData moveItem(
    ScenarioDraftData draft, {
    required String itemId,
    required int delta,
  }) {
    final ScenarioDayDraft day = draft.days.first;
    final int from = day.itemIds.indexOf(itemId);
    if (from < 0) return draft;
    final ScenarioItemDraft item = draft.items.firstWhere(
      (ScenarioItemDraft value) => value.id == itemId,
    );
    if (item.orderLocked) return draft;
    final int to = (from + delta).clamp(0, day.itemIds.length - 1);
    if (from == to) return draft;
    final List<String> itemIds = <String>[...day.itemIds];
    itemIds.insert(to, itemIds.removeAt(from));
    return _next(
      draft.copyWith(
        days: <ScenarioDayDraft>[
          _copyDay(day, itemIds: itemIds),
          ...draft.days.skip(1),
        ],
      ),
    );
  }

  ScenarioDraftData updateItem(
    ScenarioDraftData draft,
    String itemId, {
    ScenarioItemRole? role,
    bool? orderLocked,
    bool? timeLocked,
    bool? selected,
  }) {
    return _next(
      draft.copyWith(
        items: draft.items
            .map((ScenarioItemDraft item) {
              if (item.id != itemId) return item;
              final ScenarioItemRole nextRole = role ?? item.role;
              return ScenarioItemDraft(
                id: item.id,
                dayId: item.dayId,
                startLocationId: item.startLocationId,
                endLocationId: item.endLocationId,
                kind: item.kind,
                source: item.source,
                sourceStatus: item.sourceStatus,
                schedule: item.schedule,
                durationMinutes: item.durationMinutes,
                cost: item.cost,
                orderLocked: orderLocked ?? item.orderLocked,
                timeLocked: timeLocked ?? item.timeLocked,
                role: nextRole,
                alternativeGroupId: nextRole == ScenarioItemRole.alternative
                    ? (item.alternativeGroupId ?? _idGenerator.generate())
                    : null,
                selected: nextRole == ScenarioItemRole.mandatory
                    ? true
                    : (selected ?? item.selected),
                publicNote: item.publicNote,
              );
            })
            .toList(growable: false),
      ),
    );
  }

  ScenarioDraftData removeItem(ScenarioDraftData draft, String itemId) {
    return _next(
      draft.copyWith(
        items: draft.items
            .where((ScenarioItemDraft item) => item.id != itemId)
            .toList(growable: false),
        days: draft.days
            .map(
              (ScenarioDayDraft day) => _copyDay(
                day,
                itemIds: day.itemIds
                    .where((String id) => id != itemId)
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        unscheduledItemIds: draft.unscheduledItemIds
            .where((String id) => id != itemId)
            .toList(growable: false),
        legs: draft.legs
            .where((leg) => leg.fromItemId != itemId && leg.toItemId != itemId)
            .toList(growable: false),
      ),
    );
  }

  ScenarioReadinessResult evaluate(ScenarioDraftData draft) =>
      _evaluateReadiness(draft);

  ScenarioDraftData _appendItem(
    ScenarioDraftData draft,
    ScenarioItemDraft item,
  ) {
    final ScenarioDayDraft day = draft.days.first;
    return _next(
      draft.copyWith(
        items: <ScenarioItemDraft>[...draft.items, item],
        days: <ScenarioDayDraft>[
          _copyDay(day, itemIds: <String>[...day.itemIds, item.id]),
          ...draft.days.skip(1),
        ],
      ),
    );
  }

  ScenarioDraftData _next(ScenarioDraftData draft) => draft.copyWith(
    revision: draft.revision + 1,
    totals: _evaluateReadiness(draft).totals,
  );

  static ScenarioScheduleDraft _scheduleFor(ScenarioDraftData draft) =>
      ScenarioScheduleDraft(
        mode: ScenarioTimeMode.flexible,
        planned: draft.dateMode == ScenarioDateMode.template
            ? const ScenarioTemplatePlannedTimeDraft(startDayIndex: 0)
            : const ScenarioDatedPlannedTimeDraft(),
      );

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

  static ScenarioItemDraft _copyItem(
    ScenarioItemDraft item, {
    required ScenarioScheduleDraft schedule,
  }) => ScenarioItemDraft(
    id: item.id,
    dayId: item.dayId,
    startLocationId: item.startLocationId,
    endLocationId: item.endLocationId,
    kind: item.kind,
    source: item.source,
    sourceStatus: item.sourceStatus,
    schedule: schedule,
    durationMinutes: item.durationMinutes,
    cost: item.cost,
    orderLocked: item.orderLocked,
    timeLocked: item.timeLocked,
    role: item.role,
    alternativeGroupId: item.alternativeGroupId,
    selected: item.selected,
    publicNote: item.publicNote,
  );

  static ScenarioItemDraft? _itemById(ScenarioDraftData draft, String itemId) {
    for (final ScenarioItemDraft item in draft.items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  static String? _existingLegId(
    ScenarioDraftData draft,
    String fromItemId,
    String toItemId,
  ) {
    for (final ScenarioLegDraft leg in draft.legs) {
      if (leg.fromItemId == fromItemId && leg.toItemId == toItemId) {
        return leg.id;
      }
    }
    return null;
  }
}
