import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/models/scenario_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_logistics_draft.dart';

void main() {
  test('Scenario persists through Create draft schema v8', () {
    final ScenarioCreateCoordinator coordinator = ScenarioCreateCoordinator(
      idGenerator: _SequentialIdGenerator(),
    );
    var scenario = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    scenario = coordinator.addTimeBlock(
      scenario,
      title: 'Coffee',
      durationMinutes: 45,
    );
    scenario = coordinator.addTimeBlock(
      scenario,
      title: 'Cinema',
      durationMinutes: 120,
    );
    final CreateDraftEntity source =
        CreateDraftEntity.defaults(
          organizerId: 'user-1',
          organizerEmail: 'user@example.com',
          organizerName: 'User',
          timezone: 'Europe/Riga',
          currency: 'EUR',
        ).copyWith(
          objectType: CreateObjectType.scenario,
          title: 'Riga evening',
          scenarioData: scenario,
          clearEventData: true,
          visibility: VisibilityType.private,
        );

    final Map<String, dynamic> json = CreateDraftModel.fromEntity(
      source,
    ).toJson();
    final CreateDraftEntity restored = CreateDraftModel.fromJson(
      json,
    ).toEntity();

    expect(json['schemaVersion'], 8);
    expect(json['objectType'], 'scenario');
    expect(restored.objectType, CreateObjectType.scenario);
    expect(restored.scenarioData!.items, hasLength(2));
    expect(restored.scenarioData!.days.single.itemIds, hasLength(2));
  });

  test('legacy quick_plan is promoted only when Scenario-shaped', () {
    final CreateDraftEntity base = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'User',
      timezone: 'Europe/Riga',
      currency: 'EUR',
    );
    final Map<String, dynamic> lightweight = CreateDraftModel.fromEntity(
      base.copyWith(objectType: CreateObjectType.quickPlan),
    ).toJson();
    final Map<String, dynamic> scenarioShaped = <String, dynamic>{
      ...lightweight,
      'sectionData': <String, Object?>{
        'scenario': <String, Object?>{
          'schemaVersion': 1,
          'days': <Object?>[],
          'defaultTimezoneId': 'Europe/Riga',
        },
      },
    };

    expect(
      CreateDraftModel.fromJson(lightweight).toEntity().objectType,
      CreateObjectType.quickPlan,
    );
    expect(
      CreateDraftModel.fromJson(scenarioShaped).toEntity().objectType,
      CreateObjectType.scenario,
    );
  });

  test('dated mode normalizes day metadata and item schedules', () {
    final ScenarioCreateCoordinator coordinator = ScenarioCreateCoordinator(
      idGenerator: _SequentialIdGenerator(),
    );
    var scenario = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    scenario = coordinator.addTimeBlock(
      scenario,
      title: 'Coffee',
      durationMinutes: 45,
    );
    scenario = coordinator.addCustomStop(
      scenario,
      title: 'Canal park',
      durationMinutes: 60,
      latitude: 56.9496,
      longitude: 24.1052,
    );
    scenario = coordinator.updateContext(
      scenario,
      dateMode: ScenarioDateMode.dated,
    );
    scenario = coordinator.addTimeBlock(
      scenario,
      title: 'Late snack',
      durationMinutes: 30,
    );

    expect(scenario.days.single.localDate, isNotNull);
    expect(
      scenario.items.every(
        (ScenarioItemDraft item) =>
            item.schedule.planned is ScenarioDatedPlannedTimeDraft,
      ),
      isTrue,
    );
    expect(scenario.locations.single.title, 'Canal park');
    expect(coordinator.evaluate(scenario).canSaveToMyScenarios, isTrue);
  });

  test('new Latvia Scenario treats own car as a primary mode', () {
    final ScenarioCreateCoordinator coordinator = ScenarioCreateCoordinator(
      idGenerator: _SequentialIdGenerator(),
    );

    final ScenarioDraftData scenario = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );

    expect(scenario.schemaVersion, 2);
    expect(scenario.constraints.primaryTravelMode, ScenarioTravelMode.car);
    expect(
      scenario.constraints.allowedTravelModes,
      containsAll(<ScenarioTravelMode>[
        ScenarioTravelMode.car,
        ScenarioTravelMode.walking,
        ScenarioTravelMode.transit,
      ]),
    );
    expect(scenario.constraints.vehicleProfile.enabled, isTrue);
    expect(scenario.capabilities.plannedTransport, isTrue);
    expect(scenario.capabilities.liveLogistics, isFalse);
  });

  test('manual car leg never infers fuel and keeps explicit extra cost', () {
    final ScenarioCreateCoordinator coordinator = ScenarioCreateCoordinator(
      idGenerator: _SequentialIdGenerator(),
    );
    var scenario = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    scenario = coordinator.addCustomStop(
      scenario,
      title: 'Cesis',
      durationMinutes: 60,
      latitude: 57.3119,
      longitude: 25.2746,
    );
    scenario = coordinator.addCustomStop(
      scenario,
      title: 'Sigulda',
      durationMinutes: 60,
      latitude: 57.1537,
      longitude: 24.8595,
    );
    scenario = coordinator.upsertManualLeg(
      scenario,
      fromItemId: scenario.items.first.id,
      toItemId: scenario.items.last.id,
      mode: ScenarioTravelMode.car,
      durationMinutes: 45,
      distanceKm: 50,
    );

    final ScenarioLegDraft leg = scenario.legs.single;
    expect(leg.source, ScenarioLegSource.manual);
    expect(leg.lockedByUser, isTrue);
    expect(leg.durationMinutes, 45);
    expect(leg.distanceM, 50000);
    expect(leg.cost.components, isEmpty);
    expect(coordinator.evaluate(scenario).totals.localTravelMinutes, 45);

    scenario = coordinator.upsertManualLeg(
      scenario,
      fromItemId: scenario.items.first.id,
      toItemId: scenario.items.last.id,
      mode: ScenarioTravelMode.car,
      durationMinutes: 45,
      distanceKm: 50,
      otherCostMinorUnits: 900,
    );
    expect(scenario.legs.single.cost.components, hasLength(1));
    expect(
      scenario.legs.single.cost.components.single.componentCode,
      'travel_extra',
    );
    expect(scenario.legs.single.cost.components.single.amount?.minorUnits, 900);
  });

  test('planned transport persists a non-live schedule snapshot', () {
    final ScenarioCreateCoordinator coordinator = ScenarioCreateCoordinator(
      idGenerator: _SequentialIdGenerator(),
    );
    var scenario = coordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    scenario = coordinator.addPlannedTransport(
      scenario,
      kind: ScenarioPlannedTransportKind.train,
      carrierName: 'Vivi',
      serviceLabel: 'Train 802',
      durationMinutes: 92,
      plannedDeparture: const ScenarioLocalTimeDraft(hour: 9, minute: 12),
      plannedArrival: const ScenarioLocalTimeDraft(hour: 10, minute: 44),
    );

    final Map<String, Object?> json = ScenarioDraftMapper.toJson(scenario);
    final ScenarioDraftData restored = ScenarioDraftMapper.fromJson(json);
    final source =
        restored.items.single.source as ScenarioPlannedTransportSourceDraft;

    expect(source.kind, ScenarioPlannedTransportKind.train);
    expect(source.scheduleSnapshot?.providerCode, 'manual');
    expect(
      source.scheduleSnapshot?.freshness,
      ScenarioScheduleFreshness.unknown,
    );
    expect(source.scheduleSnapshot?.plannedDeparture?.hhmm, '09:12');
    expect(restored.capabilities.liveLogistics, isFalse);
    expect(coordinator.evaluate(restored).totals.plannedTransportMinutes, 92);
  });
}

class _SequentialIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => 'scenario-id-${_value++}';
}
