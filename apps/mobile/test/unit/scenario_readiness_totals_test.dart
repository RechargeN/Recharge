import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/scenario_budget_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_logistics_draft.dart';
import 'package:recharge/features/create/domain/usecases/evaluate_scenario_readiness_usecase.dart';

void main() {
  const EvaluateScenarioReadinessUseCase evaluate =
      EvaluateScenarioReadinessUseCase();

  test(
    'derives time, distance and from-total without treating unknown as zero',
    () {
      final ScenarioReadinessResult result = evaluate(_fixture());
      final ScenarioTotalsDraft totals = result.totals;

      expect(result.canSaveToMyScenarios, isTrue);
      expect(totals.activityMinutes, 60);
      expect(totals.plannedBlockMinutes, 30);
      expect(totals.localTravelMinutes, 15);
      expect(totals.plannedTransportMinutes, 0);
      expect(totals.activeItemCount, 2);
      expect(totals.knownEmbeddedRouteDistanceM, 5000);
      expect(totals.knownLocalTravelDistanceM, 850);
      expect(totals.displayIncludedExperienceCost!.minorUnits, 2000);
      expect(totals.displayIncludedLocalTravelCost!.minorUnits, 500);
      expect(totals.displayFromTotalCost!.minorUnits, 2500);
      expect(totals.estimatedCostCount, 1);
      expect(totals.unknownCostCount, 1);
      expect(totals.originalCurrencySubtotals.single.knownMinorUnits, 2000);
      expect(totals.originalCurrencySubtotals.single.estimatedMinorUnits, 500);
      expect(totals.dayTotals.single.elapsedMinutes, 105);
      expect(totals.dayTotals.single.unresolvedValueCount, 0);
    },
  );

  test('unknown leg keeps partial minutes but makes elapsed time unknown', () {
    final ScenarioReadinessResult result = evaluate(
      _fixture(unresolvedLeg: true),
    );

    expect(result.totals.activityMinutes, 60);
    expect(result.totals.plannedBlockMinutes, 30);
    expect(result.totals.localTravelMinutes, 0);
    expect(result.totals.unresolvedLegCount, 1);
    expect(result.totals.dayTotals.single.elapsedMinutes, isNull);
    expect(result.totals.dayTotals.single.unresolvedValueCount, 1);
  });

  test('unselected optional item does not enter totals', () {
    final ScenarioDraftData source = _fixture();
    final ScenarioItemDraft optional = ScenarioItemDraft(
      id: 'item-optional',
      dayId: 'day-1',
      kind: ScenarioItemKind.timeBlock,
      source: const ScenarioTimeBlockSourceDraft(title: 'Optional dessert'),
      sourceStatus: ScenarioSourceStatus.ready,
      schedule: const ScenarioScheduleDraft(
        mode: ScenarioTimeMode.flexible,
        planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
      ),
      durationMinutes: 45,
      cost: const ScenarioCostDraft(
        components: <ScenarioMoneyEstimateDraft>[
          ScenarioMoneyEstimateDraft(
            componentCode: 'dessert',
            knowledge: ScenarioPriceKnowledge.known,
            amount: ScenarioMoneyDraft(minorUnits: 900, currencyCode: 'EUR'),
            basis: ScenarioPriceBasis.perBooking,
            source: ScenarioPriceSource.manual,
          ),
        ],
      ),
      orderLocked: false,
      timeLocked: false,
      role: ScenarioItemRole.optional,
      selected: false,
      publicNote: '',
    );
    final ScenarioDraftData withOptional = source.copyWith(
      days: <ScenarioDayDraft>[
        ScenarioDayDraft(
          id: source.days.single.id,
          title: source.days.single.title,
          dayIndex: 0,
          itemIds: const <String>['item-route', 'item-break', 'item-optional'],
        ),
      ],
      items: <ScenarioItemDraft>[...source.items, optional],
    );

    final ScenarioTotalsDraft totals = evaluate(withOptional).totals;

    expect(totals.activeItemCount, 2);
    expect(totals.plannedBlockMinutes, 30);
    expect(totals.displayFromTotalCost!.minorUnits, 2500);
  });

  test('confirmed free totals remain zero instead of becoming unknown', () {
    const ScenarioCostDraft free = ScenarioCostDraft(
      components: <ScenarioMoneyEstimateDraft>[
        ScenarioMoneyEstimateDraft(
          componentCode: 'admission',
          knowledge: ScenarioPriceKnowledge.free,
          amount: ScenarioMoneyDraft(minorUnits: 0, currencyCode: 'EUR'),
          basis: ScenarioPriceBasis.perBooking,
          source: ScenarioPriceSource.catalog,
        ),
      ],
    );
    final ScenarioTotalsDraft totals = evaluate(
      _fixture(
        routeCost: free,
        breakCost: const ScenarioCostDraft(),
        legCost: const ScenarioCostDraft(),
      ),
    ).totals;

    expect(totals.displayIncludedExperienceCost, isNotNull);
    expect(totals.displayIncludedExperienceCost!.minorUnits, 0);
    expect(totals.displayFromTotalCost, isNotNull);
    expect(totals.displayFromTotalCost!.minorUnits, 0);
    expect(totals.unknownCostCount, 0);
  });

  test('does not expose a partial display total without exchange rates', () {
    const ScenarioCostDraft dollars = ScenarioCostDraft(
      components: <ScenarioMoneyEstimateDraft>[
        ScenarioMoneyEstimateDraft(
          componentCode: 'ticket',
          knowledge: ScenarioPriceKnowledge.known,
          amount: ScenarioMoneyDraft(minorUnits: 3000, currencyCode: 'USD'),
          basis: ScenarioPriceBasis.perBooking,
          source: ScenarioPriceSource.catalog,
        ),
      ],
    );
    final ScenarioTotalsDraft totals = evaluate(
      _fixture(
        routeCost: dollars,
        breakCost: const ScenarioCostDraft(),
        legCost: const ScenarioCostDraft(),
      ),
    ).totals;

    expect(totals.displayIncludedExperienceCost, isNull);
    expect(totals.displayFromTotalCost, isNull);
    expect(totals.unknownCostCount, 1);
    expect(totals.originalCurrencySubtotals.single.currencyCode, 'USD');
    expect(totals.originalCurrencySubtotals.single.knownMinorUnits, 3000);
  });
}

ScenarioDraftData _fixture({
  bool unresolvedLeg = false,
  ScenarioCostDraft? routeCost,
  ScenarioCostDraft? breakCost,
  ScenarioCostDraft? legCost,
}) {
  const ScenarioLocationDraft location = ScenarioLocationDraft(
    id: 'location-1',
    point: ScenarioGeoPointDraft(latitude: 56.9496, longitude: 24.1052),
    title: 'Riga centre',
    disclosure: ScenarioLocationDisclosure.public,
    timezoneId: 'Europe/Riga',
  );
  final ScenarioItemDraft route = ScenarioItemDraft(
    id: 'item-route',
    dayId: 'day-1',
    startLocationId: 'location-1',
    endLocationId: 'location-1',
    kind: ScenarioItemKind.route,
    source: ScenarioCatalogObjectSourceDraft(
      objectId: 'route-1',
      objectType: ScenarioCatalogObjectType.route,
      snapshot: ScenarioObjectSnapshotDraft(
        title: 'Riga walk',
        distanceM: 5000,
      ),
    ),
    sourceStatus: ScenarioSourceStatus.ready,
    schedule: ScenarioScheduleDraft(
      mode: ScenarioTimeMode.flexible,
      planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
    ),
    durationMinutes: 60,
    cost:
        routeCost ??
        const ScenarioCostDraft(
          components: <ScenarioMoneyEstimateDraft>[
            ScenarioMoneyEstimateDraft(
              componentCode: 'ticket',
              knowledge: ScenarioPriceKnowledge.known,
              amount: ScenarioMoneyDraft(minorUnits: 1000, currencyCode: 'EUR'),
              basis: ScenarioPriceBasis.perPerson,
              source: ScenarioPriceSource.catalog,
            ),
          ],
        ),
    orderLocked: false,
    timeLocked: false,
    role: ScenarioItemRole.mandatory,
    selected: true,
    publicNote: '',
  );
  final ScenarioItemDraft breakItem = ScenarioItemDraft(
    id: 'item-break',
    dayId: 'day-1',
    startLocationId: 'location-1',
    endLocationId: 'location-1',
    kind: ScenarioItemKind.timeBlock,
    source: ScenarioTimeBlockSourceDraft(title: 'Coffee break'),
    sourceStatus: ScenarioSourceStatus.ready,
    schedule: ScenarioScheduleDraft(
      mode: ScenarioTimeMode.flexible,
      planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
    ),
    durationMinutes: 30,
    cost:
        breakCost ??
        const ScenarioCostDraft(
          components: <ScenarioMoneyEstimateDraft>[
            ScenarioMoneyEstimateDraft(
              componentCode: 'coffee',
              knowledge: ScenarioPriceKnowledge.unknown,
              source: ScenarioPriceSource.manual,
            ),
          ],
        ),
    orderLocked: false,
    timeLocked: false,
    role: ScenarioItemRole.mandatory,
    selected: true,
    publicNote: '',
  );

  return ScenarioDraftData(
    schemaVersion: ScenarioDraftData.currentSchemaVersion,
    revision: 1,
    format: ScenarioFormat.city,
    dateMode: ScenarioDateMode.template,
    defaultTimezoneId: 'Europe/Riga',
    displayCurrencyCode: 'EUR',
    party: const ScenarioPartyDraft(
      peopleCount: 2,
      kind: ScenarioPartyKind.couple,
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
        itemIds: <String>['item-route', 'item-break'],
      ),
    ],
    locations: const <ScenarioLocationDraft>[location],
    items: <ScenarioItemDraft>[route, breakItem],
    unscheduledItemIds: const <String>[],
    legs: <ScenarioLegDraft>[
      ScenarioLegDraft(
        id: 'leg-1',
        dayId: 'day-1',
        fromItemId: 'item-route',
        toItemId: 'item-break',
        fromLocationId: 'location-1',
        toLocationId: 'location-1',
        mode: ScenarioTravelMode.walking,
        source: unresolvedLeg
            ? ScenarioLegSource.unknown
            : ScenarioLegSource.estimate,
        status: unresolvedLeg
            ? ScenarioLegStatus.failed
            : ScenarioLegStatus.ready,
        distanceM: unresolvedLeg ? null : 850,
        durationMinutes: unresolvedLeg ? null : 15,
        cost:
            legCost ??
            const ScenarioCostDraft(
              components: <ScenarioMoneyEstimateDraft>[
                ScenarioMoneyEstimateDraft(
                  componentCode: 'transit',
                  knowledge: ScenarioPriceKnowledge.estimated,
                  amount: ScenarioMoneyDraft(
                    minorUnits: 500,
                    currencyCode: 'EUR',
                  ),
                  basis: ScenarioPriceBasis.perBooking,
                  source: ScenarioPriceSource.provider,
                  confidence: 0.8,
                ),
              ],
            ),
      ),
    ],
    totals: const ScenarioTotalsDraft.empty(),
    origin: const ScenarioOriginDraft(type: ScenarioOriginType.manual),
    capabilities: const ScenarioCapabilitiesDraft(),
    unknownFields: const <String, Object?>{},
  );
}
