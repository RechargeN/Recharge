import '../entities/scenario_budget_draft.dart';
import '../entities/scenario_draft_data.dart';
import '../entities/scenario_item_draft.dart';
import '../entities/scenario_logistics_draft.dart';
import '../entities/scenario_validation_issue.dart';

class ValidateScenarioDraftUseCase {
  const ValidateScenarioDraftUseCase();

  ScenarioValidationResult call(
    ScenarioDraftData draft, {
    ScenarioValidationTarget target = ScenarioValidationTarget.draft,
  }) {
    final List<ScenarioValidationIssue> issues = <ScenarioValidationIssue>[];

    void issue({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity = ScenarioValidationSeverity.error,
      String? dayId,
      String? itemId,
      String? legId,
    }) {
      issues.add(
        ScenarioValidationIssue(
          code: code,
          severity: target == ScenarioValidationTarget.draft
              ? ScenarioValidationSeverity.warning
              : severity,
          path: path,
          message: message,
          dayId: dayId,
          itemId: itemId,
          legId: legId,
        ),
      );
    }

    if (draft.schemaVersion != ScenarioDraftData.currentSchemaVersion) {
      issue(
        code: 'schema_version_unsupported',
        path: 'schemaVersion',
        message: 'Scenario schema version is unsupported',
      );
    }
    if (draft.revision < 0) {
      issue(
        code: 'revision_negative',
        path: 'revision',
        message: 'Revision cannot be negative',
      );
    }
    if (!_isIanaTimezone(draft.defaultTimezoneId)) {
      issue(
        code: 'default_timezone_invalid',
        path: 'defaultTimezoneId',
        message: 'Choose a valid IANA timezone',
      );
    }
    if (!_isCurrency(draft.displayCurrencyCode)) {
      issue(
        code: 'display_currency_invalid',
        path: 'displayCurrencyCode',
        message: 'Display currency must use a three-letter ISO code',
      );
    }
    _validateParty(draft, issue);
    _validateConstraints(draft, issue);

    if (draft.days.isEmpty) {
      issue(
        code: 'days_minimum',
        path: 'days',
        message: 'A Scenario must contain at least one calendar day',
      );
    }
    if (draft.days.length > 30) {
      issue(
        code: 'days_limit',
        path: 'days',
        message: 'A Scenario can contain at most 30 days',
      );
    }
    if (draft.items.length > 250) {
      issue(
        code: 'items_limit',
        path: 'items',
        message: 'A Scenario can contain at most 250 items',
      );
    }
    if (draft.unscheduledItemIds.length > 50) {
      issue(
        code: 'unscheduled_items_limit',
        path: 'unscheduledItemIds',
        message: 'Keep at most 50 unscheduled items',
      );
    }

    final Map<String, ScenarioDayDraft> days = _uniqueById(
      draft.days,
      (ScenarioDayDraft value) => value.id,
      path: 'days',
      duplicateCode: 'day_id_duplicate',
      issue: issue,
    );
    final Map<String, ScenarioLocationDraft> locations = _uniqueById(
      draft.locations,
      (ScenarioLocationDraft value) => value.id,
      path: 'locations',
      duplicateCode: 'location_id_duplicate',
      issue: issue,
    );
    final Map<String, ScenarioItemDraft> items = _uniqueById(
      draft.items,
      (ScenarioItemDraft value) => value.id,
      path: 'items',
      duplicateCode: 'item_id_duplicate',
      issue: issue,
    );
    final Map<String, ScenarioLegDraft> legs = _uniqueById(
      draft.legs,
      (ScenarioLegDraft value) => value.id,
      path: 'legs',
      duplicateCode: 'leg_id_duplicate',
      issue: issue,
    );

    final List<int> indices =
        draft.days
            .map((ScenarioDayDraft day) => day.dayIndex)
            .toList(growable: false)
          ..sort();
    for (int index = 0; index < indices.length; index += 1) {
      if (indices[index] != index) {
        issue(
          code: 'day_index_not_contiguous',
          path: 'days',
          message: 'Day indices must form a continuous 0-based sequence',
        );
        break;
      }
    }

    final Set<String> scheduledIds = <String>{};
    for (final ScenarioDayDraft day in draft.days) {
      _validateDay(day, draft, locations, issue);
      final Set<String> localIds = <String>{};
      for (final String itemId in day.itemIds) {
        if (!localIds.add(itemId)) {
          issue(
            code: 'day_item_duplicate',
            path: 'days.itemIds',
            message: 'An item can appear only once in a day',
            dayId: day.id,
            itemId: itemId,
          );
        }
        if (!scheduledIds.add(itemId)) {
          issue(
            code: 'item_scheduled_multiple_days',
            path: 'days.itemIds',
            message: 'An item can belong to only one day',
            dayId: day.id,
            itemId: itemId,
          );
        }
        final ScenarioItemDraft? item = items[itemId];
        if (item == null) {
          issue(
            code: 'day_item_dangling',
            path: 'days.itemIds',
            message: 'Day references a missing item',
            dayId: day.id,
            itemId: itemId,
          );
        } else if (item.dayId != day.id) {
          issue(
            code: 'item_day_mismatch',
            path: 'items.dayId',
            message: 'Item dayId must match its day membership',
            dayId: day.id,
            itemId: itemId,
          );
        }
      }
    }

    final Set<String> unscheduled = <String>{};
    for (final String itemId in draft.unscheduledItemIds) {
      if (!unscheduled.add(itemId)) {
        issue(
          code: 'unscheduled_item_duplicate',
          path: 'unscheduledItemIds',
          message: 'Unscheduled item ids must be unique',
          itemId: itemId,
        );
      }
      final ScenarioItemDraft? item = items[itemId];
      if (item == null) {
        issue(
          code: 'unscheduled_item_dangling',
          path: 'unscheduledItemIds',
          message: 'Unscheduled list references a missing item',
          itemId: itemId,
        );
      }
      if (scheduledIds.contains(itemId) || item?.dayId != null) {
        issue(
          code: 'unscheduled_item_has_day',
          path: 'unscheduledItemIds',
          message: 'An unscheduled item cannot belong to a day',
          itemId: itemId,
        );
      }
    }

    for (final ScenarioLocationDraft location in draft.locations) {
      _validateLocation(location, issue);
    }
    for (final ScenarioItemDraft item in draft.items) {
      _validateItem(item, draft, days, locations, issue);
      if (item.dayId != null && !scheduledIds.contains(item.id)) {
        issue(
          code: 'item_missing_from_day',
          path: 'items.dayId',
          message: 'Scheduled item must appear in its day itemIds',
          itemId: item.id,
          dayId: item.dayId,
        );
      }
      if (item.dayId == null && !unscheduled.contains(item.id)) {
        issue(
          code: 'item_orphaned',
          path: 'items',
          message: 'Item must be scheduled or explicitly unscheduled',
          itemId: item.id,
        );
      }
    }
    _validateAlternatives(draft, issue);
    for (final ScenarioLegDraft leg in legs.values) {
      _validateLeg(leg, days, items, locations, issue);
    }
    _validateCapabilities(draft, issue);

    final int activeCount = draft.activeScheduledItems.length;
    if (activeCount > 200) {
      issue(
        code: 'active_items_limit',
        path: 'items',
        message: 'A Scenario can contain at most 200 active items',
      );
    }
    if (target != ScenarioValidationTarget.draft && activeCount < 2) {
      issue(
        code: 'active_items_minimum',
        path: 'items',
        message: 'Add at least two active scheduled items',
      );
    }
    if (target != ScenarioValidationTarget.draft) {
      final List<String> persistedIds = <String>[
        ...draft.days.map((ScenarioDayDraft value) => value.id),
        ...draft.locations.map((ScenarioLocationDraft value) => value.id),
        ...draft.items.map((ScenarioItemDraft value) => value.id),
        ...draft.legs.map((ScenarioLegDraft value) => value.id),
      ];
      if (persistedIds.any((String id) => id.startsWith('loc_'))) {
        issue(
          code: 'temporary_id_not_materialized',
          path: 'ids',
          message: 'Temporary local ids must be replaced before saving',
        );
      }
      for (final ScenarioItemDraft item in draft.items) {
        final ScenarioItemSourceDraft source = item.source;
        if (source is ScenarioCatalogObjectSourceDraft &&
            source.objectId.startsWith('loc_')) {
          issue(
            code: 'temporary_catalog_reference',
            path: 'items.source.objectId',
            message: 'Catalog references require permanent object ids',
            itemId: item.id,
          );
        }
      }
    }

    if (target == ScenarioValidationTarget.unlistedShare ||
        target == ScenarioValidationTarget.publish) {
      final bool enabled = target == ScenarioValidationTarget.unlistedShare
          ? draft.capabilities.unlistedShare
          : draft.capabilities.publicPublish;
      if (!enabled) {
        issue(
          code: target == ScenarioValidationTarget.unlistedShare
              ? 'unlisted_share_disabled'
              : 'public_publish_disabled',
          path: 'capabilities',
          message: 'Requested distribution capability is disabled',
        );
      }
      for (final ScenarioLocationDraft location in draft.locations) {
        if (location.disclosure == ScenarioLocationDisclosure.private &&
            _isLocationUsedByActiveItem(draft, location.id)) {
          issue(
            code: 'private_location_in_distribution',
            path: 'locations.disclosure',
            message: 'Private locations cannot enter a distributed payload',
          );
        }
      }
    }

    if (target == ScenarioValidationTarget.publish ||
        target == ScenarioValidationTarget.start) {
      for (final ScenarioItemDraft item in draft.items) {
        if (item.role == ScenarioItemRole.mandatory &&
            !draft.isScheduled(item)) {
          issue(
            code: 'mandatory_item_unscheduled',
            path: 'items.dayId',
            message: 'Mandatory items must be scheduled',
            itemId: item.id,
          );
        }
        if (item.role == ScenarioItemRole.mandatory &&
            item.sourceStatus == ScenarioSourceStatus.unavailable) {
          issue(
            code: 'mandatory_source_unavailable',
            path: 'items.sourceStatus',
            message: 'Replace or remove the unavailable mandatory item',
            itemId: item.id,
          );
        }
      }
    }

    if (target == ScenarioValidationTarget.start &&
        draft.dateMode != ScenarioDateMode.dated) {
      issue(
        code: 'start_requires_dated_mode',
        path: 'dateMode',
        message: 'Starting a Scenario requires real dates',
      );
    }

    return ScenarioValidationResult(
      target: target,
      issues: List<ScenarioValidationIssue>.unmodifiable(issues),
    );
  }

  void _validateParty(
    ScenarioDraftData draft,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    if (draft.party.peopleCount < 1 || draft.party.peopleCount > 100) {
      issue(
        code: 'party_size_invalid',
        path: 'party.peopleCount',
        message: 'Party size must be between 1 and 100',
        severity: ScenarioValidationSeverity.error,
      );
    }
    final int children = draft.party.childrenCount ?? 0;
    if (children < 0 || children > draft.party.peopleCount) {
      issue(
        code: 'children_count_invalid',
        path: 'party.childrenCount',
        message: 'Children count must fit the party size',
        severity: ScenarioValidationSeverity.error,
      );
    }
  }

  void _validateConstraints(
    ScenarioDraftData draft,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    final ScenarioMoneyDraft? budget = draft.constraints.totalBudgetLimit;
    if (budget != null && !budget.isStructurallyValid) {
      issue(
        code: 'budget_invalid',
        path: 'constraints.totalBudgetLimit',
        message: 'Budget must be non-negative and use an ISO currency',
        severity: ScenarioValidationSeverity.error,
      );
    }
    if (draft.constraints.allowedTravelModes.isEmpty) {
      issue(
        code: 'travel_modes_empty',
        path: 'constraints.allowedTravelModes',
        message: 'Choose at least one allowed travel mode',
        severity: ScenarioValidationSeverity.error,
      );
    }
    if (!draft.constraints.allowedTravelModes.contains(
      draft.constraints.primaryTravelMode,
    )) {
      issue(
        code: 'primary_travel_mode_not_allowed',
        path: 'constraints.primaryTravelMode',
        message: 'Primary travel mode must be allowed',
        severity: ScenarioValidationSeverity.error,
      );
    }
    final ScenarioVehicleProfileDraft vehicle =
        draft.constraints.vehicleProfile;
    if ((vehicle.passengerSeats ?? 0) < 0) {
      issue(
        code: 'vehicle_profile_invalid',
        path: 'constraints.vehicleProfile',
        message: 'Vehicle passenger seats must be valid',
        severity: ScenarioValidationSeverity.error,
      );
    }
    if ((draft.constraints.maxWalkingMinutesPerLeg ?? 0) < 0 ||
        (draft.constraints.maxTravelMinutesPerDay ?? 0) < 0) {
      issue(
        code: 'travel_limit_negative',
        path: 'constraints',
        message: 'Travel limits cannot be negative',
        severity: ScenarioValidationSeverity.error,
      );
    }
  }

  void _validateDay(
    ScenarioDayDraft day,
    ScenarioDraftData draft,
    Map<String, ScenarioLocationDraft> locations,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    if (day.id.trim().isEmpty) {
      issue(
        code: 'day_id_missing',
        path: 'days.id',
        message: 'Day id is required',
        severity: ScenarioValidationSeverity.error,
        dayId: day.id,
      );
    }
    if (draft.dateMode == ScenarioDateMode.dated) {
      if (day.localDate == null || !day.localDate!.isValid) {
        issue(
          code: 'dated_day_date_missing',
          path: 'days.localDate',
          message: 'Dated Scenario days require a valid local date',
          severity: ScenarioValidationSeverity.error,
          dayId: day.id,
        );
      }
      if (!_isIanaTimezone(day.timezoneId ?? '')) {
        issue(
          code: 'dated_day_timezone_missing',
          path: 'days.timezoneId',
          message: 'Dated Scenario days require an IANA timezone',
          severity: ScenarioValidationSeverity.error,
          dayId: day.id,
        );
      }
    } else if (day.localDate != null) {
      issue(
        code: 'template_day_has_date',
        path: 'days.localDate',
        message: 'Template days must not store real dates',
        severity: ScenarioValidationSeverity.error,
        dayId: day.id,
      );
    }
    for (final String? locationId in <String?>[
      day.startLocationId,
      day.endLocationId,
    ]) {
      if (locationId != null && !locations.containsKey(locationId)) {
        issue(
          code: 'day_location_dangling',
          path: 'days.locationId',
          message: 'Day references a missing location',
          severity: ScenarioValidationSeverity.error,
          dayId: day.id,
        );
      }
    }
  }

  void _validateLocation(
    ScenarioLocationDraft location,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    if (location.id.trim().isEmpty || !location.point.isValid) {
      issue(
        code: 'location_invalid',
        path: 'locations',
        message: 'Location requires an id and valid coordinates',
        severity: ScenarioValidationSeverity.error,
      );
    }
    final bool hasObjectId = location.sourceObjectId != null;
    final bool hasObjectType = location.sourceObjectType != null;
    if (hasObjectId != hasObjectType) {
      issue(
        code: 'location_source_incomplete',
        path: 'locations.sourceObjectId',
        message: 'Location source type and id must be set together',
        severity: ScenarioValidationSeverity.error,
      );
    }
  }

  void _validateItem(
    ScenarioItemDraft item,
    ScenarioDraftData draft,
    Map<String, ScenarioDayDraft> days,
    Map<String, ScenarioLocationDraft> locations,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    if (item.id.trim().isEmpty) {
      issue(
        code: 'item_id_missing',
        path: 'items.id',
        message: 'Item id is required',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
    if (item.dayId != null && !days.containsKey(item.dayId)) {
      issue(
        code: 'item_day_dangling',
        path: 'items.dayId',
        message: 'Item references a missing day',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
    for (final String? locationId in <String?>[
      item.startLocationId,
      item.endLocationId,
    ]) {
      if (locationId != null && !locations.containsKey(locationId)) {
        issue(
          code: 'item_location_dangling',
          path: 'items.locationId',
          message: 'Item references a missing location',
          severity: ScenarioValidationSeverity.error,
          itemId: item.id,
        );
      }
    }
    if (_requiresDuration(item.kind) &&
        (item.durationMinutes == null || item.durationMinutes! <= 0)) {
      issue(
        code: 'item_duration_missing',
        path: 'items.durationMinutes',
        message: 'Item requires a positive duration',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
    if (item.role == ScenarioItemRole.mandatory && !item.selected) {
      issue(
        code: 'mandatory_item_not_selected',
        path: 'items.selected',
        message: 'Mandatory items are always selected',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
    if (item.role == ScenarioItemRole.alternative &&
        (item.alternativeGroupId?.trim().isEmpty ?? true)) {
      issue(
        code: 'alternative_group_missing',
        path: 'items.alternativeGroupId',
        message: 'Alternative items require a group id',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
    if (item.role != ScenarioItemRole.alternative &&
        item.alternativeGroupId != null) {
      issue(
        code: 'alternative_group_unexpected',
        path: 'items.alternativeGroupId',
        message: 'Only alternative items can belong to an alternative group',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
    _validateSource(item, locations, issue);
    _validateSchedule(item, draft.dateMode, issue);
    _validateCost(item.cost, item.id, issue);
    if (item.sourceStatus == ScenarioSourceStatus.stale) {
      issue(
        code: 'source_stale',
        path: 'items.sourceStatus',
        message: 'Source snapshot is stale and should be refreshed',
        severity: ScenarioValidationSeverity.warning,
        itemId: item.id,
      );
    }
    if (item.sourceStatus == ScenarioSourceStatus.unresolved) {
      issue(
        code: 'source_unresolved',
        path: 'items.sourceStatus',
        message: 'Resolve the item source before distribution or start',
        severity: ScenarioValidationSeverity.warning,
        itemId: item.id,
      );
    }
  }

  void _validateSource(
    ScenarioItemDraft item,
    Map<String, ScenarioLocationDraft> locations,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    bool compatible = false;
    final ScenarioItemSourceDraft source = item.source;
    if (source is ScenarioCatalogObjectSourceDraft) {
      compatible =
          source.objectId.trim().isNotEmpty &&
          switch (item.kind) {
            ScenarioItemKind.visit =>
              source.objectType == ScenarioCatalogObjectType.place,
            ScenarioItemKind.event =>
              source.objectType == ScenarioCatalogObjectType.event,
            ScenarioItemKind.activity =>
              source.objectType == ScenarioCatalogObjectType.activity,
            ScenarioItemKind.route =>
              source.objectType == ScenarioCatalogObjectType.route,
            ScenarioItemKind.bookableSession =>
              source.objectType == ScenarioCatalogObjectType.bookableSession,
            ScenarioItemKind.stay =>
              source.objectType == ScenarioCatalogObjectType.place ||
                  source.objectType ==
                      ScenarioCatalogObjectType.bookableSession,
            ScenarioItemKind.plannedTransport ||
            ScenarioItemKind.timeBlock => false,
          };
    } else if (source is ScenarioCustomLocationSourceDraft) {
      compatible =
          <ScenarioItemKind>{
            ScenarioItemKind.visit,
            ScenarioItemKind.activity,
            ScenarioItemKind.stay,
          }.contains(item.kind) &&
          locations.containsKey(source.locationId);
      final Set<String> itemLocationIds = <String>{
        if (item.startLocationId != null) item.startLocationId!,
        if (item.endLocationId != null) item.endLocationId!,
      };
      if (compatible &&
          itemLocationIds.isNotEmpty &&
          itemLocationIds.any((String id) => id != source.locationId)) {
        compatible = false;
      }
    } else if (source is ScenarioPlannedTransportSourceDraft) {
      compatible = item.kind == ScenarioItemKind.plannedTransport;
      final ScenarioScheduleSnapshotDraft? snapshot = source.scheduleSnapshot;
      if (snapshot?.freshness == ScenarioScheduleFreshness.stale) {
        issue(
          code: 'planned_schedule_stale',
          path: 'items.source.scheduleSnapshot',
          message: 'Planned schedule is stale and must be rechecked',
          severity: ScenarioValidationSeverity.warning,
          itemId: item.id,
        );
      }
    } else if (source is ScenarioTimeBlockSourceDraft) {
      compatible =
          item.kind == ScenarioItemKind.timeBlock &&
          source.title.trim().isNotEmpty;
    }
    if (!compatible) {
      issue(
        code: 'item_source_incompatible',
        path: 'items.source',
        message: 'Item kind and source are incompatible',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
  }

  void _validateSchedule(
    ScenarioItemDraft item,
    ScenarioDateMode dateMode,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    final ScenarioPlannedTimeDraft planned = item.schedule.planned;
    final ScenarioCalculatedTimeDraft? calculated = item.schedule.calculated;
    final bool typeMatches = switch (dateMode) {
      ScenarioDateMode.template =>
        planned is ScenarioTemplatePlannedTimeDraft &&
            (calculated == null ||
                calculated is ScenarioTemplateCalculatedTimeDraft),
      ScenarioDateMode.dated =>
        planned is ScenarioDatedPlannedTimeDraft &&
            (calculated == null ||
                calculated is ScenarioDatedCalculatedTimeDraft),
    };
    if (!typeMatches) {
      issue(
        code: 'schedule_date_mode_mismatch',
        path: 'items.schedule',
        message: 'Schedule representation must match Scenario date mode',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
      return;
    }
    if (planned is ScenarioTemplatePlannedTimeDraft) {
      _validateWindow(
        item,
        planned.windowStart,
        planned.windowEnd,
        planned.windowEndDayOffset,
        issue,
      );
      if (planned.startDayIndex < 0 ||
          (planned.endDayIndex != null &&
              planned.endDayIndex! < planned.startDayIndex)) {
        issue(
          code: 'template_day_range_invalid',
          path: 'items.schedule.planned',
          message: 'Template day range is invalid',
          severity: ScenarioValidationSeverity.error,
          itemId: item.id,
        );
      }
    } else if (planned is ScenarioDatedPlannedTimeDraft) {
      _validateWindow(
        item,
        planned.windowStart,
        planned.windowEnd,
        planned.windowEndDayOffset,
        issue,
      );
      if (item.schedule.mode == ScenarioTimeMode.fixed &&
          planned.fixedStartAtUtc == null) {
        issue(
          code: 'fixed_start_missing',
          path: 'items.schedule.planned.fixedStartAtUtc',
          message: 'Fixed dated items require a start instant',
          severity: ScenarioValidationSeverity.error,
          itemId: item.id,
        );
      }
      if (planned.fixedStartAtUtc != null &&
          planned.fixedEndAtUtc != null &&
          !planned.fixedEndAtUtc!.isAfter(planned.fixedStartAtUtc!)) {
        issue(
          code: 'fixed_interval_invalid',
          path: 'items.schedule.planned.fixedEndAtUtc',
          message: 'Fixed end must be after fixed start',
          severity: ScenarioValidationSeverity.error,
          itemId: item.id,
        );
      }
    }
  }

  void _validateWindow(
    ScenarioItemDraft item,
    ScenarioLocalTimeDraft? start,
    ScenarioLocalTimeDraft? end,
    int endDayOffset,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    if (item.schedule.mode != ScenarioTimeMode.window) {
      return;
    }
    if (start == null || end == null || !start.isValid || !end.isValid) {
      issue(
        code: 'window_bounds_missing',
        path: 'items.schedule.planned',
        message: 'Window schedule requires valid start and end times',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    } else if (endDayOffset == 0 && start.minuteOfDay >= end.minuteOfDay) {
      issue(
        code: 'window_order_invalid',
        path: 'items.schedule.planned',
        message: 'Same-day window end must be after its start',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
    if (endDayOffset != 0 && endDayOffset != 1) {
      issue(
        code: 'window_day_offset_invalid',
        path: 'items.schedule.planned.windowEndDayOffset',
        message: 'Window day offset can only be 0 or 1',
        severity: ScenarioValidationSeverity.error,
        itemId: item.id,
      );
    }
  }

  void _validateCost(
    ScenarioCostDraft cost,
    String itemId,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    final Map<String, Set<ScenarioPriceBasis>> componentBases =
        <String, Set<ScenarioPriceBasis>>{};
    for (final ScenarioMoneyEstimateDraft estimate in cost.components) {
      final ScenarioMoneyDraft? amount = estimate.amount;
      final bool amountValid = switch (estimate.knowledge) {
        ScenarioPriceKnowledge.free =>
          amount != null &&
              amount.minorUnits == 0 &&
              amount.isStructurallyValid,
        ScenarioPriceKnowledge.known || ScenarioPriceKnowledge.estimated =>
          amount != null && amount.isStructurallyValid,
        ScenarioPriceKnowledge.unknown => amount == null,
      };
      if (estimate.componentCode.trim().isEmpty || !amountValid) {
        issue(
          code: 'cost_component_invalid',
          path: 'items.cost.components',
          message: 'Cost component knowledge and amount are inconsistent',
          severity: ScenarioValidationSeverity.error,
          itemId: itemId,
        );
      }
      if (estimate.knowledge == ScenarioPriceKnowledge.estimated &&
          estimate.confidence != null &&
          (estimate.confidence! < 0 || estimate.confidence! > 1)) {
        issue(
          code: 'cost_confidence_invalid',
          path: 'items.cost.components.confidence',
          message: 'Estimated price confidence must be between 0 and 1',
          severity: ScenarioValidationSeverity.error,
          itemId: itemId,
        );
      }
      if (estimate.knowledge != ScenarioPriceKnowledge.estimated &&
          estimate.confidence != null) {
        issue(
          code: 'cost_confidence_unexpected',
          path: 'items.cost.components.confidence',
          message: 'Only estimated prices can have confidence',
          severity: ScenarioValidationSeverity.error,
          itemId: itemId,
        );
      }
      final ScenarioPriceBasis? basis = estimate.basis;
      if (basis != null) {
        final Set<ScenarioPriceBasis> bases = componentBases.putIfAbsent(
          estimate.componentCode,
          () => <ScenarioPriceBasis>{},
        );
        if (!bases.add(basis)) {
          issue(
            code: 'cost_basis_duplicate',
            path: 'items.cost.components.basis',
            message: 'Price basis cannot be duplicated in one component',
            severity: ScenarioValidationSeverity.error,
            itemId: itemId,
          );
        }
      }
      if (estimate.knowledge == ScenarioPriceKnowledge.unknown) {
        issue(
          code: 'cost_unknown',
          path: 'items.cost.components',
          message: 'Item price is unknown',
          severity: ScenarioValidationSeverity.warning,
          itemId: itemId,
        );
      }
    }
    for (final Set<ScenarioPriceBasis> bases in componentBases.values) {
      if (bases.contains(ScenarioPriceBasis.perPerson) &&
          (bases.contains(ScenarioPriceBasis.perAdult) ||
              bases.contains(ScenarioPriceBasis.perChild))) {
        issue(
          code: 'cost_basis_overlap',
          path: 'items.cost.components.basis',
          message: 'Per-person price overlaps adult or child pricing',
          severity: ScenarioValidationSeverity.error,
          itemId: itemId,
        );
      }
    }
  }

  void _validateAlternatives(
    ScenarioDraftData draft,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    final Map<String, List<ScenarioItemDraft>> groups =
        <String, List<ScenarioItemDraft>>{};
    for (final ScenarioItemDraft item in draft.items) {
      if (item.role != ScenarioItemRole.alternative ||
          item.alternativeGroupId == null) {
        continue;
      }
      groups
          .putIfAbsent(item.alternativeGroupId!, () => <ScenarioItemDraft>[])
          .add(item);
    }
    if (groups.length > 20 ||
        groups.values.any(
          (List<ScenarioItemDraft> values) => values.length > 5,
        )) {
      issue(
        code: 'alternative_limit',
        path: 'items.alternativeGroupId',
        message: 'Use at most 20 alternative groups with 5 items each',
        severity: ScenarioValidationSeverity.error,
      );
    }
    for (final MapEntry<String, List<ScenarioItemDraft>> entry
        in groups.entries) {
      final int selected = entry.value
          .where((ScenarioItemDraft item) => item.selected)
          .length;
      if (selected > 1) {
        issue(
          code: 'alternative_multiple_selected',
          path: 'items.selected',
          message: 'Only one alternative can be selected in a group',
          severity: ScenarioValidationSeverity.error,
        );
      }
    }
  }

  void _validateLeg(
    ScenarioLegDraft leg,
    Map<String, ScenarioDayDraft> days,
    Map<String, ScenarioItemDraft> items,
    Map<String, ScenarioLocationDraft> locations,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    if (!days.containsKey(leg.dayId) ||
        !locations.containsKey(leg.fromLocationId) ||
        !locations.containsKey(leg.toLocationId) ||
        (leg.fromItemId != null && !items.containsKey(leg.fromItemId)) ||
        (leg.toItemId != null && !items.containsKey(leg.toItemId)) ||
        (leg.fromItemId == null && leg.toItemId == null)) {
      issue(
        code: 'leg_reference_invalid',
        path: 'legs',
        message: 'Leg contains a dangling or incomplete reference',
        severity: ScenarioValidationSeverity.error,
        legId: leg.id,
      );
    }
    if ((leg.distanceM ?? 0) < 0 || (leg.durationMinutes ?? 0) < 0) {
      issue(
        code: 'leg_value_negative',
        path: 'legs',
        message: 'Leg distance and duration cannot be negative',
        severity: ScenarioValidationSeverity.error,
        legId: leg.id,
      );
    }
    if (leg.source == ScenarioLegSource.manual) {
      issue(
        code: 'manual_logistics',
        path: 'legs.source',
        message: 'Travel time was entered manually',
        severity: ScenarioValidationSeverity.warning,
        legId: leg.id,
      );
    }
    if (leg.source == ScenarioLegSource.schedule &&
        leg.scheduleSnapshot == null) {
      issue(
        code: 'schedule_snapshot_missing',
        path: 'legs.scheduleSnapshot',
        message: 'Scheduled travel requires a plan snapshot',
        severity: ScenarioValidationSeverity.error,
        legId: leg.id,
      );
    }
    if (leg.scheduleSnapshot?.freshness == ScenarioScheduleFreshness.stale) {
      issue(
        code: 'schedule_stale',
        path: 'legs.scheduleSnapshot.freshness',
        message: 'Planned schedule is stale and must be rechecked',
        severity: ScenarioValidationSeverity.warning,
        legId: leg.id,
      );
    }
  }

  void _validateCapabilities(
    ScenarioDraftData draft,
    void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  ) {
    if (!draft.capabilities.multiDay &&
        (draft.format == ScenarioFormat.weekend ||
            draft.format == ScenarioFormat.trip)) {
      issue(
        code: 'multi_day_format_disabled',
        path: 'format',
        message: 'Weekend and trip formats require the multi-day capability',
        severity: ScenarioValidationSeverity.error,
      );
    }
    if (!draft.capabilities.multiDay && draft.days.length > 1) {
      issue(
        code: 'multi_day_disabled',
        path: 'capabilities.multiDay',
        message: 'Multi-day data is present while the capability is disabled',
        severity: ScenarioValidationSeverity.error,
      );
    }
    for (final ScenarioItemDraft item in draft.items) {
      final bool disabled =
          (item.kind == ScenarioItemKind.stay && !draft.capabilities.stay) ||
          (item.kind == ScenarioItemKind.plannedTransport &&
              !draft.capabilities.plannedTransport) ||
          (item.role == ScenarioItemRole.alternative &&
              !draft.capabilities.alternatives);
      if (disabled && item.isRoleActive) {
        issue(
          code: 'item_capability_disabled',
          path: 'capabilities',
          message: 'Active item uses a disabled Scenario capability',
          severity: ScenarioValidationSeverity.error,
          itemId: item.id,
        );
      }
    }
    if (!draft.capabilities.multiCurrency) {
      final Set<String> costCurrencies = <String>{
        for (final ScenarioItemDraft item in draft.items)
          for (final ScenarioMoneyEstimateDraft estimate
              in item.cost.components)
            if (estimate.amount != null) estimate.amount!.currencyCode,
        for (final ScenarioLegDraft leg in draft.legs)
          for (final ScenarioMoneyEstimateDraft estimate in leg.cost.components)
            if (estimate.amount != null) estimate.amount!.currencyCode,
      };
      if (costCurrencies.any(
        (String code) => code != draft.displayCurrencyCode,
      )) {
        issue(
          code: 'multi_currency_disabled',
          path: 'capabilities.multiCurrency',
          message:
              'Foreign-currency costs require the multi-currency capability',
          severity: ScenarioValidationSeverity.error,
        );
      }
    }
  }

  static bool _requiresDuration(ScenarioItemKind kind) => switch (kind) {
    ScenarioItemKind.visit ||
    ScenarioItemKind.event ||
    ScenarioItemKind.activity ||
    ScenarioItemKind.route ||
    ScenarioItemKind.bookableSession ||
    ScenarioItemKind.timeBlock => true,
    ScenarioItemKind.stay || ScenarioItemKind.plannedTransport => false,
  };

  static bool _isLocationUsedByActiveItem(
    ScenarioDraftData draft,
    String locationId,
  ) => draft.activeScheduledItems.any(
    (ScenarioItemDraft item) =>
        item.startLocationId == locationId ||
        item.endLocationId == locationId ||
        (item.source is ScenarioCustomLocationSourceDraft &&
            (item.source as ScenarioCustomLocationSourceDraft).locationId ==
                locationId),
  );

  static bool _isCurrency(String value) =>
      RegExp(r'^[A-Z]{3}$').hasMatch(value);

  static bool _isIanaTimezone(String value) =>
      value == 'UTC' ||
      RegExp(r'^[A-Za-z_]+(?:/[A-Za-z0-9_+\-]+)+$').hasMatch(value);

  static Map<String, T> _uniqueById<T>(
    Iterable<T> values,
    String Function(T value) idOf, {
    required String path,
    required String duplicateCode,
    required void Function({
      required String code,
      required String path,
      required String message,
      ScenarioValidationSeverity severity,
      String? dayId,
      String? itemId,
      String? legId,
    })
    issue,
  }) {
    final Map<String, T> result = <String, T>{};
    for (final T value in values) {
      final String id = idOf(value);
      if (id.trim().isEmpty) {
        continue;
      }
      if (result.containsKey(id)) {
        issue(
          code: duplicateCode,
          path: path,
          message: 'Identifiers must be unique',
          severity: ScenarioValidationSeverity.error,
        );
      } else {
        result[id] = value;
      }
    }
    return result;
  }
}
