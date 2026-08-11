import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/quick_plan_conversion_coordinator.dart';
import 'package:recharge/features/create/application/scenario_conversion_handoff_store.dart';
import 'package:recharge/features/create/data/datasources/quick_plan_conversion_memory_datasource.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/quick_plan_conversion.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/usecases/expand_quick_plan_to_scenario_usecase.dart';

void main() {
  late InMemoryQuickPlanConversionSource source;
  late _SequentialIdGenerator ids;
  late ExpandQuickPlanToScenarioUseCase expand;

  setUp(() {
    source = InMemoryQuickPlanConversionSource();
    ids = _SequentialIdGenerator();
    expand = ExpandQuickPlanToScenarioUseCase(source: source, idGenerator: ids);
  });

  test('creates an independent Scenario in source stop order', () async {
    final QuickPlanConversionSnapshot snapshot = _snapshot();
    source.put(snapshot);

    final ExpandQuickPlanToScenarioResult result = await expand(
      const ExpandQuickPlanToScenarioRequest(
        quickPlanId: 'quick-plan-1',
        expectedQuickPlanRevision: 4,
        selectedStopIds: <String>{'stop-b', 'stop-a'},
        copyPrivateNotes: true,
        requesterId: 'owner-1',
      ),
    );

    expect(result.succeeded, isTrue);
    expect(
      result.scenario!.origin!.type,
      ScenarioOriginType.quickPlanConversion,
    );
    expect(result.scenario!.origin!.sourceId, 'quick-plan-1');
    expect(result.scenario!.origin!.sourceRevision, 4);
    expect(result.scenario!.items, hasLength(2));
    final Map<String, String> locationTitles = <String, String>{
      for (final ScenarioLocationDraft location in result.scenario!.locations)
        location.id: location.title,
    };
    expect(
      result.scenario!.items.map(
        (ScenarioItemDraft item) => locationTitles[item.startLocationId],
      ),
      <String>['Coffee', 'Cinema'],
    );
    expect(
      result.scenario!.locations.every(
        (ScenarioLocationDraft location) =>
            location.disclosure == ScenarioLocationDisclosure.private,
      ),
      isTrue,
    );
    expect(result.quickPlanStopIdToScenarioItemId.keys, <String>[
      'stop-a',
      'stop-b',
    ]);
    expect(result.privateNotesByScenarioItemId.values, <String>['Window seat']);
    expect(snapshot.revision, 4);
    expect(snapshot.stops.map((stop) => stop.id), <String>['stop-a', 'stop-b']);
  });

  test('revision mismatch blocks until explicitly continued', () async {
    source.put(_snapshot(revision: 5));
    const ExpandQuickPlanToScenarioRequest request =
        ExpandQuickPlanToScenarioRequest(
          quickPlanId: 'quick-plan-1',
          expectedQuickPlanRevision: 4,
          selectedStopIds: <String>{'stop-a'},
          copyPrivateNotes: false,
          requesterId: 'owner-1',
        );

    final ExpandQuickPlanToScenarioResult blocked = await expand(request);
    final ExpandQuickPlanToScenarioResult continued = await expand(
      const ExpandQuickPlanToScenarioRequest(
        quickPlanId: 'quick-plan-1',
        expectedQuickPlanRevision: 4,
        selectedStopIds: <String>{'stop-a'},
        copyPrivateNotes: false,
        requesterId: 'owner-1',
        continueWithLatestSnapshot: true,
      ),
    );

    expect(blocked.scenario, isNull);
    expect(blocked.requiresRevisionConfirmation, isTrue);
    expect(continued.scenario, isNotNull);
    expect(continued.sourceRevision, 5);
  });

  test('copy permission is enforced without revealing source data', () async {
    source.put(_snapshot());

    final ExpandQuickPlanToScenarioResult result = await expand(
      const ExpandQuickPlanToScenarioRequest(
        quickPlanId: 'quick-plan-1',
        expectedQuickPlanRevision: 4,
        selectedStopIds: <String>{'stop-a'},
        copyPrivateNotes: true,
        requesterId: 'stranger',
      ),
    );

    expect(result.scenario, isNull);
    expect(
      result.issues.single.code,
      QuickPlanConversionIssueCode.sourceNotFoundOrForbidden,
    );
    expect(result.privateNotesByScenarioItemId, isEmpty);
  });

  test('repeated Expand creates different Scenario and relation ids', () async {
    source.put(_snapshot());
    const ExpandQuickPlanToScenarioRequest request =
        ExpandQuickPlanToScenarioRequest(
          quickPlanId: 'quick-plan-1',
          expectedQuickPlanRevision: 4,
          selectedStopIds: <String>{'stop-a', 'stop-b'},
          copyPrivateNotes: false,
          requesterId: 'owner-1',
        );
    final QuickPlanConversionCoordinator coordinator =
        QuickPlanConversionCoordinator(
          expand: expand,
          idGenerator: ids,
          runtimeDefaults: const CreateRuntimeDefaults(
            marketCityId: 'riga',
            timezone: 'Europe/Riga',
            country: 'LV',
            city: 'Riga',
            currency: 'EUR',
          ),
        );

    final QuickPlanConversionMaterialization first = await coordinator.expand(
      quickPlanId: request.quickPlanId,
      expectedQuickPlanRevision: request.expectedQuickPlanRevision,
      selectedStopIds: request.selectedStopIds,
      copyPrivateNotes: request.copyPrivateNotes,
      requesterId: request.requesterId,
      requesterEmail: 'owner@example.com',
      requesterName: 'owner',
      scenarioTitle: 'Evening',
    );
    final QuickPlanConversionMaterialization second = await coordinator.expand(
      quickPlanId: request.quickPlanId,
      expectedQuickPlanRevision: request.expectedQuickPlanRevision,
      selectedStopIds: request.selectedStopIds,
      copyPrivateNotes: request.copyPrivateNotes,
      requesterId: request.requesterId,
      requesterEmail: 'owner@example.com',
      requesterName: 'owner',
      scenarioTitle: 'Evening',
    );

    expect(first.draft!.id, isNot(second.draft!.id));
    expect(
      first.draft!.scenarioData!.items.map((item) => item.id).toSet(),
      isNot(second.draft!.scenarioData!.items.map((item) => item.id).toSet()),
    );
    expect(first.draft!.visibility, VisibilityType.private);
    expect(first.draft!.objectType, CreateObjectType.scenario);

    final ScenarioConversionHandoffStore handoff =
        ScenarioConversionHandoffStore();
    final String handoffId = handoff.put(first.draft!);
    expect(handoff.contains(handoffId), isTrue);
    expect(handoff.take(handoffId), same(first.draft));
    expect(handoff.take(handoffId), isNull);
  });

  test('unavailable selected stop is retained as unresolved copy', () async {
    source.put(_snapshot(secondAvailable: false));

    final ExpandQuickPlanToScenarioResult result = await expand(
      const ExpandQuickPlanToScenarioRequest(
        quickPlanId: 'quick-plan-1',
        expectedQuickPlanRevision: 4,
        selectedStopIds: <String>{'stop-b'},
        copyPrivateNotes: false,
        requesterId: 'owner-1',
      ),
    );

    expect(
      result.scenario!.items.single.sourceStatus,
      ScenarioSourceStatus.unavailable,
    );
    expect(
      result.issues.map((issue) => issue.code),
      contains(QuickPlanConversionIssueCode.stopUnavailable),
    );
  });
}

QuickPlanConversionSnapshot _snapshot({
  int revision = 4,
  bool secondAvailable = true,
}) {
  return QuickPlanConversionSnapshot(
    id: 'quick-plan-1',
    revision: revision,
    ownerId: 'owner-1',
    title: 'Quick evening',
    timezoneId: 'Europe/Riga',
    currencyCode: 'EUR',
    readableByUserIds: const <String>{'owner-1'},
    stops: <QuickPlanConversionStopSnapshot>[
      const QuickPlanConversionStopSnapshot(
        id: 'stop-a',
        title: 'Coffee',
        durationMinutes: 45,
        latitude: 56.95,
        longitude: 24.1,
        isFree: false,
        priceMinorUnits: 500,
        available: true,
        requesterPrivateNote: 'Window seat',
      ),
      QuickPlanConversionStopSnapshot(
        id: 'stop-b',
        title: 'Cinema',
        durationMinutes: 120,
        latitude: 56.96,
        longitude: 24.11,
        isFree: false,
        priceMinorUnits: 1200,
        available: secondAvailable,
      ),
    ],
  );
}

class _SequentialIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => 'id-${_value++}';
}
