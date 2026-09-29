import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/scenario_budget_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_logistics_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_validation_issue.dart';
import 'package:recharge/features/create/domain/usecases/validate_scenario_draft_usecase.dart';

void main() {
  const ValidateScenarioDraftUseCase validate = ValidateScenarioDraftUseCase();

  test('valid personal city/day Scenario is ready to save', () {
    final ScenarioValidationResult result = validate(
      _validDraft(),
      target: ScenarioValidationTarget.myScenarios,
    );

    expect(result.isValid, isTrue);
    expect(
      result.issues.where(
        (ScenarioValidationIssue issue) =>
            issue.severity == ScenarioValidationSeverity.error,
      ),
      isEmpty,
    );
  });

  test(
    'detects broken day ordering, duplicate membership and dangling ids',
    () {
      final ScenarioDraftData source = _validDraft();
      final ScenarioDraftData broken = source.copyWith(
        days: <ScenarioDayDraft>[
          ScenarioDayDraft(
            id: 'day-1',
            title: 'Broken',
            dayIndex: 2,
            itemIds: const <String>['item-1', 'item-1', 'missing-item'],
          ),
        ],
      );

      final ScenarioValidationResult result = validate(
        broken,
        target: ScenarioValidationTarget.myScenarios,
      );
      final Set<String> codes = result.issues
          .map((ScenarioValidationIssue issue) => issue.code)
          .toSet();

      expect(result.isValid, isFalse);
      expect(codes, contains('day_index_not_contiguous'));
      expect(codes, contains('day_item_duplicate'));
      expect(codes, contains('day_item_dangling'));
      expect(codes, contains('item_missing_from_day'));
    },
  );

  test('allows incomplete draft save but exposes typed warnings', () {
    final ScenarioDraftData empty = ScenarioDraftData.defaults().copyWith(
      defaultTimezoneId: '',
    );

    final ScenarioValidationResult result = validate(
      empty,
      target: ScenarioValidationTarget.draft,
    );

    expect(result.isValid, isTrue);
    expect(result.issues, isNotEmpty);
    expect(
      result.issues.every(
        (ScenarioValidationIssue issue) =>
            issue.severity == ScenarioValidationSeverity.warning,
      ),
      isTrue,
    );
  });

  test('Scenario outside draft state requires at least one day', () {
    final result = validate(
      ScenarioDraftData.defaults(),
      target: ScenarioValidationTarget.myScenarios,
    );

    expect(result.isValid, isFalse);
    expect(result.issues.map((issue) => issue.code), contains('days_minimum'));
  });

  test('blocks multiple selected alternatives in one group', () {
    final ScenarioDraftData source = _validDraft();
    final ScenarioItemDraft first = _visit(
      id: 'alternative-1',
      role: ScenarioItemRole.alternative,
      alternativeGroupId: 'rain-plan',
    );
    final ScenarioItemDraft second = _visit(
      id: 'alternative-2',
      role: ScenarioItemRole.alternative,
      alternativeGroupId: 'rain-plan',
    );
    final ScenarioDraftData alternatives = source.copyWith(
      capabilities: const ScenarioCapabilitiesDraft(alternatives: true),
      days: const <ScenarioDayDraft>[
        ScenarioDayDraft(
          id: 'day-1',
          title: 'Day 1',
          dayIndex: 0,
          itemIds: <String>['alternative-1', 'alternative-2'],
        ),
      ],
      items: <ScenarioItemDraft>[first, second],
    );

    final ScenarioValidationResult result = validate(
      alternatives,
      target: ScenarioValidationTarget.myScenarios,
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((ScenarioValidationIssue issue) => issue.code),
      contains('alternative_multiple_selected'),
    );
  });

  test('date mode must match schedule representation and day metadata', () {
    final ScenarioDraftData source = _validDraft();
    final ScenarioDraftData dated = source.copyWith(
      dateMode: ScenarioDateMode.dated,
    );

    final ScenarioValidationResult result = validate(
      dated,
      target: ScenarioValidationTarget.myScenarios,
    );
    final Set<String> codes = result.issues
        .map((ScenarioValidationIssue issue) => issue.code)
        .toSet();

    expect(codes, contains('dated_day_date_missing'));
    expect(codes, contains('dated_day_timezone_missing'));
    expect(codes, contains('schedule_date_mode_mismatch'));
  });

  test('distribution rejects private active locations and disabled gate', () {
    final ScenarioDraftData source = _validDraft();
    final ScenarioValidationResult result = validate(
      source,
      target: ScenarioValidationTarget.unlistedShare,
    );
    final Set<String> codes = result.issues
        .map((ScenarioValidationIssue issue) => issue.code)
        .toSet();

    expect(result.isValid, isFalse);
    expect(codes, contains('unlisted_share_disabled'));
    expect(codes, contains('private_location_in_distribution'));
  });

  test('save rejects temporary ids and temporary catalog references', () {
    final ScenarioDraftData source = _validDraft();
    final ScenarioItemDraft temporaryReference = _visit(
      id: 'item-2',
      objectId: 'loc_unpublished_place',
    );
    final ScenarioDraftData temporary = source.copyWith(
      locations: <ScenarioLocationDraft>[
        ...source.locations,
        const ScenarioLocationDraft(
          id: 'loc_custom_home',
          point: ScenarioGeoPointDraft(latitude: 56.95, longitude: 24.1),
          title: 'Temporary',
          disclosure: ScenarioLocationDisclosure.private,
        ),
      ],
      items: <ScenarioItemDraft>[source.items.first, temporaryReference],
    );

    final ScenarioValidationResult result = validate(
      temporary,
      target: ScenarioValidationTarget.myScenarios,
    );
    final Set<String> codes = result.issues
        .map((ScenarioValidationIssue issue) => issue.code)
        .toSet();

    expect(codes, contains('temporary_id_not_materialized'));
    expect(codes, contains('temporary_catalog_reference'));
  });

  test('per-person price cannot overlap child pricing for one component', () {
    const ScenarioCostDraft overlapping = ScenarioCostDraft(
      components: <ScenarioMoneyEstimateDraft>[
        ScenarioMoneyEstimateDraft(
          componentCode: 'admission',
          knowledge: ScenarioPriceKnowledge.known,
          amount: ScenarioMoneyDraft(minorUnits: 1000, currencyCode: 'EUR'),
          basis: ScenarioPriceBasis.perPerson,
          source: ScenarioPriceSource.manual,
        ),
        ScenarioMoneyEstimateDraft(
          componentCode: 'admission',
          knowledge: ScenarioPriceKnowledge.known,
          amount: ScenarioMoneyDraft(minorUnits: 500, currencyCode: 'EUR'),
          basis: ScenarioPriceBasis.perChild,
          source: ScenarioPriceSource.manual,
        ),
      ],
    );
    final ScenarioDraftData source = _validDraft();
    final ScenarioDraftData priced = source.copyWith(
      items: <ScenarioItemDraft>[
        _visit(id: 'item-1', cost: overlapping),
        source.items.last,
      ],
    );

    final ScenarioValidationResult result = validate(
      priced,
      target: ScenarioValidationTarget.myScenarios,
    );

    expect(
      result.issues.map((ScenarioValidationIssue issue) => issue.code),
      contains('cost_basis_overlap'),
    );
  });

  test('accepts multi-segment IANA timezone identifiers', () {
    final ScenarioDraftData source = _validDraft().copyWith(
      defaultTimezoneId: 'America/Argentina/Buenos_Aires',
    );

    final ScenarioValidationResult result = validate(
      source,
      target: ScenarioValidationTarget.myScenarios,
    );

    expect(
      result.issues.map((ScenarioValidationIssue issue) => issue.code),
      isNot(contains('default_timezone_invalid')),
    );
  });

  test('keeps weekend and foreign-currency data behind independent gates', () {
    const ScenarioCostDraft dollars = ScenarioCostDraft(
      components: <ScenarioMoneyEstimateDraft>[
        ScenarioMoneyEstimateDraft(
          componentCode: 'ticket',
          knowledge: ScenarioPriceKnowledge.known,
          amount: ScenarioMoneyDraft(minorUnits: 2500, currencyCode: 'USD'),
          basis: ScenarioPriceBasis.perBooking,
          source: ScenarioPriceSource.catalog,
        ),
      ],
    );
    final ScenarioDraftData source = _validDraft();
    final ScenarioDraftData gated = source.copyWith(
      format: ScenarioFormat.weekend,
      items: <ScenarioItemDraft>[
        _visit(id: 'item-1', cost: dollars),
        source.items.last,
      ],
    );

    final ScenarioValidationResult result = validate(
      gated,
      target: ScenarioValidationTarget.myScenarios,
    );
    final Set<String> codes = result.issues
        .map((ScenarioValidationIssue issue) => issue.code)
        .toSet();

    expect(codes, contains('multi_day_format_disabled'));
    expect(codes, contains('multi_currency_disabled'));
  });
}

ScenarioDraftData _validDraft() {
  final ScenarioItemDraft first = _visit(id: 'item-1');
  final ScenarioItemDraft second = _visit(id: 'item-2');
  return ScenarioDraftData(
    schemaVersion: ScenarioDraftData.currentSchemaVersion,
    revision: 1,
    format: ScenarioFormat.city,
    dateMode: ScenarioDateMode.template,
    defaultTimezoneId: 'Europe/Riga',
    displayCurrencyCode: 'EUR',
    party: const ScenarioPartyDraft(
      peopleCount: 2,
      kind: ScenarioPartyKind.friends,
    ),
    constraints: const ScenarioConstraintsDraft(
      budgetBasis: ScenarioBudgetBasis.wholeGroup,
      primaryTravelMode: ScenarioTravelMode.walking,
      allowedTravelModes: <ScenarioTravelMode>{ScenarioTravelMode.walking},
      vehicleProfile: ScenarioVehicleProfileDraft.disabled(),
      pace: ScenarioPace.balanced,
      interestCategoryIds: <String>{},
      accessibilityRequirementIds: <String>{},
      freeExperienceItemsOnly: false,
    ),
    days: const <ScenarioDayDraft>[
      ScenarioDayDraft(
        id: 'day-1',
        title: 'Day 1',
        dayIndex: 0,
        itemIds: <String>['item-1', 'item-2'],
      ),
    ],
    locations: const <ScenarioLocationDraft>[
      ScenarioLocationDraft(
        id: 'location-1',
        point: ScenarioGeoPointDraft(latitude: 56.9496, longitude: 24.1052),
        title: 'Private starting point',
        disclosure: ScenarioLocationDisclosure.private,
        timezoneId: 'Europe/Riga',
      ),
    ],
    items: <ScenarioItemDraft>[first, second],
    unscheduledItemIds: const <String>[],
    legs: const <ScenarioLegDraft>[
      ScenarioLegDraft(
        id: 'leg-1',
        dayId: 'day-1',
        fromItemId: 'item-1',
        toItemId: 'item-2',
        fromLocationId: 'location-1',
        toLocationId: 'location-1',
        mode: ScenarioTravelMode.walking,
        source: ScenarioLegSource.manual,
        status: ScenarioLegStatus.ready,
        distanceM: 0,
        durationMinutes: 0,
        cost: ScenarioCostDraft(),
      ),
    ],
    totals: const ScenarioTotalsDraft.empty(),
    origin: const ScenarioOriginDraft(type: ScenarioOriginType.manual),
    capabilities: const ScenarioCapabilitiesDraft(),
    unknownFields: const <String, Object?>{},
  );
}

ScenarioItemDraft _visit({
  required String id,
  ScenarioItemRole role = ScenarioItemRole.mandatory,
  String? alternativeGroupId,
  String? objectId,
  ScenarioCostDraft cost = const ScenarioCostDraft(),
}) {
  return ScenarioItemDraft(
    id: id,
    dayId: 'day-1',
    startLocationId: 'location-1',
    endLocationId: 'location-1',
    kind: ScenarioItemKind.visit,
    source: ScenarioCatalogObjectSourceDraft(
      objectId: objectId ?? 'place-$id',
      objectType: ScenarioCatalogObjectType.place,
      snapshot: ScenarioObjectSnapshotDraft(title: 'Place $id'),
    ),
    sourceStatus: ScenarioSourceStatus.ready,
    schedule: const ScenarioScheduleDraft(
      mode: ScenarioTimeMode.flexible,
      planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
    ),
    durationMinutes: 60,
    cost: cost,
    orderLocked: false,
    timeLocked: false,
    role: role,
    alternativeGroupId: alternativeGroupId,
    selected: true,
    publicNote: '',
  );
}
