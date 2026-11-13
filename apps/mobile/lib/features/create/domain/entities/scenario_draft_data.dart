import 'scenario_budget_draft.dart';
import 'scenario_item_draft.dart';
import 'scenario_logistics_draft.dart';

enum ScenarioFormat { city, day, weekend, trip }

enum ScenarioDateMode { template, dated }

enum ScenarioPartyKind { solo, couple, friends, family, group, mixed }

enum ScenarioBudgetBasis { wholeGroup, perPerson }

enum ScenarioPace { relaxed, balanced, intensive }

enum ScenarioOriginType {
  publicScenario,
  quickPlanConversion,
  collection,
  details,
  search,
  smartSearch,
  mapSelection,
  manual,
}

class ScenarioOriginDraft {
  const ScenarioOriginDraft({
    required this.type,
    this.sourceId,
    this.sourceRevision,
  });

  final ScenarioOriginType type;
  final String? sourceId;
  final int? sourceRevision;
}

class ScenarioCapabilitiesDraft {
  const ScenarioCapabilitiesDraft({
    this.multiDay = false,
    this.stay = false,
    this.plannedTransport = false,
    this.alternatives = false,
    this.multiCurrency = false,
    this.optimizer = false,
    this.unlistedShare = false,
    this.publicPublish = false,
    this.liveLogistics = false,
  });

  final bool multiDay;
  final bool stay;
  final bool plannedTransport;
  final bool alternatives;
  final bool multiCurrency;
  final bool optimizer;
  final bool unlistedShare;
  final bool publicPublish;
  final bool liveLogistics;
}

class ScenarioPartyDraft {
  const ScenarioPartyDraft({
    required this.peopleCount,
    required this.kind,
    this.childrenCount,
  });

  final int peopleCount;
  final ScenarioPartyKind kind;
  final int? childrenCount;
}

class ScenarioConstraintsDraft {
  const ScenarioConstraintsDraft({
    required this.budgetBasis,
    required this.primaryTravelMode,
    required this.allowedTravelModes,
    required this.vehicleProfile,
    required this.pace,
    required this.interestCategoryIds,
    required this.accessibilityRequirementIds,
    required this.freeExperienceItemsOnly,
    this.totalBudgetLimit,
    this.maxWalkingMinutesPerLeg,
    this.maxTravelMinutesPerDay,
  });

  final ScenarioMoneyDraft? totalBudgetLimit;
  final ScenarioBudgetBasis budgetBasis;
  final ScenarioTravelMode primaryTravelMode;
  final Set<ScenarioTravelMode> allowedTravelModes;
  final ScenarioVehicleProfileDraft vehicleProfile;
  final int? maxWalkingMinutesPerLeg;
  final int? maxTravelMinutesPerDay;
  final ScenarioPace pace;
  final Set<String> interestCategoryIds;
  final Set<String> accessibilityRequirementIds;
  final bool freeExperienceItemsOnly;
}

class ScenarioDayDraft {
  const ScenarioDayDraft({
    required this.id,
    required this.title,
    required this.dayIndex,
    required this.itemIds,
    this.timezoneId,
    this.localDate,
    this.startLocationId,
    this.endLocationId,
    this.preferredStartTime,
    this.preferredEndTime,
  });

  final String id;
  final String title;
  final int dayIndex;
  final String? timezoneId;
  final ScenarioLocalDateDraft? localDate;
  final String? startLocationId;
  final String? endLocationId;
  final ScenarioLocalTimeDraft? preferredStartTime;
  final ScenarioLocalTimeDraft? preferredEndTime;
  final List<String> itemIds;
}

class ScenarioDraftData {
  const ScenarioDraftData({
    required this.schemaVersion,
    required this.revision,
    required this.format,
    required this.dateMode,
    required this.defaultTimezoneId,
    required this.displayCurrencyCode,
    required this.party,
    required this.constraints,
    required this.days,
    required this.locations,
    required this.items,
    required this.unscheduledItemIds,
    required this.legs,
    required this.totals,
    required this.capabilities,
    required this.unknownFields,
    this.updatesEnabled = true,
    this.origin,
  });

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final int revision;
  final ScenarioFormat format;
  final ScenarioDateMode dateMode;
  final String defaultTimezoneId;
  final String displayCurrencyCode;
  final ScenarioPartyDraft party;
  final ScenarioConstraintsDraft constraints;
  final List<ScenarioDayDraft> days;
  final List<ScenarioLocationDraft> locations;
  final List<ScenarioItemDraft> items;
  final List<String> unscheduledItemIds;
  final List<ScenarioLegDraft> legs;
  final ScenarioTotalsDraft totals;
  final ScenarioOriginDraft? origin;
  final ScenarioCapabilitiesDraft capabilities;
  final Map<String, Object?> unknownFields;
  final bool updatesEnabled;

  factory ScenarioDraftData.defaults({
    String timezoneId = 'Europe/Riga',
    String currencyCode = 'EUR',
  }) {
    return ScenarioDraftData(
      schemaVersion: currentSchemaVersion,
      revision: 0,
      format: ScenarioFormat.city,
      dateMode: ScenarioDateMode.template,
      defaultTimezoneId: timezoneId,
      displayCurrencyCode: currencyCode,
      party: const ScenarioPartyDraft(
        peopleCount: 1,
        kind: ScenarioPartyKind.solo,
      ),
      constraints: const ScenarioConstraintsDraft(
        budgetBasis: ScenarioBudgetBasis.wholeGroup,
        primaryTravelMode: ScenarioTravelMode.car,
        allowedTravelModes: <ScenarioTravelMode>{
          ScenarioTravelMode.car,
          ScenarioTravelMode.walking,
          ScenarioTravelMode.transit,
        },
        vehicleProfile: ScenarioVehicleProfileDraft(enabled: true),
        pace: ScenarioPace.balanced,
        interestCategoryIds: <String>{},
        accessibilityRequirementIds: <String>{},
        freeExperienceItemsOnly: false,
      ),
      days: const <ScenarioDayDraft>[],
      locations: const <ScenarioLocationDraft>[],
      items: const <ScenarioItemDraft>[],
      unscheduledItemIds: const <String>[],
      legs: const <ScenarioLegDraft>[],
      totals: const ScenarioTotalsDraft.empty(),
      origin: const ScenarioOriginDraft(type: ScenarioOriginType.manual),
      capabilities: const ScenarioCapabilitiesDraft(),
      unknownFields: const <String, Object?>{},
      updatesEnabled: true,
    );
  }

  ScenarioDraftData copyWith({
    int? schemaVersion,
    int? revision,
    ScenarioFormat? format,
    ScenarioDateMode? dateMode,
    String? defaultTimezoneId,
    String? displayCurrencyCode,
    ScenarioPartyDraft? party,
    ScenarioConstraintsDraft? constraints,
    List<ScenarioDayDraft>? days,
    List<ScenarioLocationDraft>? locations,
    List<ScenarioItemDraft>? items,
    List<String>? unscheduledItemIds,
    List<ScenarioLegDraft>? legs,
    ScenarioTotalsDraft? totals,
    ScenarioOriginDraft? origin,
    bool clearOrigin = false,
    ScenarioCapabilitiesDraft? capabilities,
    Map<String, Object?>? unknownFields,
    bool? updatesEnabled,
  }) {
    return ScenarioDraftData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      format: format ?? this.format,
      dateMode: dateMode ?? this.dateMode,
      defaultTimezoneId: defaultTimezoneId ?? this.defaultTimezoneId,
      displayCurrencyCode: displayCurrencyCode ?? this.displayCurrencyCode,
      party: party ?? this.party,
      constraints: constraints ?? this.constraints,
      days: days ?? this.days,
      locations: locations ?? this.locations,
      items: items ?? this.items,
      unscheduledItemIds: unscheduledItemIds ?? this.unscheduledItemIds,
      legs: legs ?? this.legs,
      totals: totals ?? this.totals,
      origin: clearOrigin ? null : (origin ?? this.origin),
      capabilities: capabilities ?? this.capabilities,
      unknownFields: unknownFields ?? this.unknownFields,
      updatesEnabled: updatesEnabled ?? this.updatesEnabled,
    );
  }

  bool isScheduled(ScenarioItemDraft item) {
    if (item.dayId == null || unscheduledItemIds.contains(item.id)) {
      return false;
    }
    return days.any(
      (ScenarioDayDraft day) =>
          day.id == item.dayId && day.itemIds.contains(item.id),
    );
  }

  Iterable<ScenarioItemDraft> get activeScheduledItems => items.where(
    (ScenarioItemDraft item) => item.isRoleActive && isScheduled(item),
  );
}
