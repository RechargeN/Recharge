import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/controllers/scenario_transit_picker_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/application/scenario_transit_picker_config.dart';
import 'package:recharge/features/create/application/scenario_transit_schedule_coordinator.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/scenario_transit_schedule_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/scenario/scenario_create_block.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets(
    'Apply and confirmed Replace are single undoable autosaved mutations',
    (WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(420, 900);
      addTearDown(tester.view.reset);

      final createRepository = _CreateRepository();
      final transitRepository = _TransitRepository();
      final scenarioCoordinator = ScenarioCreateCoordinator(
        idGenerator: _Ids(),
      );
      final createController = CreateController(
        loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
        saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
        publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
        analyticsService: _Analytics(),
        eventCreateCoordinator: createTestEventCoordinator(),
        scenarioCreateCoordinator: scenarioCoordinator,
        runtimeDefaults: const CreateRuntimeDefaults(
          marketCityId: 'latvia',
          timezone: 'Europe/Riga',
          country: 'LV',
          city: 'Riga',
          currency: 'EUR',
        ),
      );
      final picker = ScenarioTransitPickerController(
        coordinator: ScenarioTransitScheduleCoordinator(
          repository: transitRepository,
        ),
        config: const ScenarioTransitPickerConfig(
          pickerEnabled: true,
          stopSearchDebounce: Duration.zero,
        ),
      );
      addTearDown(createController.dispose);
      addTearDown(picker.dispose);

      await createController.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Planner',
      );
      createController.setObjectType(CreateObjectType.scenario);
      createController.updateScenarioContext(dateMode: ScenarioDateMode.dated);
      await createController.goToScenarioStep(1);
      final date =
          createController.state.draft.scenarioData!.days.single.localDate!;
      transitRepository.currentOption = _option(date: date);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: createController,
              builder: (BuildContext context, Widget? child) =>
                  SingleChildScrollView(
                    child: ScenarioCreateBlock(
                      controller: createController,
                      state: createController.state,
                      transitPickerController: picker,
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final savesBeforeApply = createRepository.saveCount;
      final undoCountBeforeApply =
          createController.state.scenarioUndoStack.length;
      final draftBeforeApply = createController.state.draft.scenarioData!;

      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('add-planned-transport')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('scenario-transit-choice-official')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('scenario-transit-origin-query')),
        'Riga',
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey<String>('scenario-transit-origin-result-origin'),
        ),
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('scenario-transit-destination-query'),
        ),
        'Sigulda',
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey<String>(
            'scenario-transit-destination-result-destination',
          ),
        ),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('scenario-transit-search-services')),
      );
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey<String>('scenario-transit-service-provider-a-trip-1'),
        ),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('scenario-transit-apply')),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      final applied = createController.state.draft.scenarioData!;
      final itemId = applied.items.single.id;
      expect(applied.items, hasLength(1));
      expect(
        createController.state.scenarioUndoStack,
        hasLength(undoCountBeforeApply + 1),
      );
      expect(createRepository.saveCount, savesBeforeApply + 1);
      expect(
        (applied.items.single.source as ScenarioPlannedTransportSourceDraft)
            .scheduleSnapshot
            ?.feedSha256,
        'a' * 64,
      );

      createController.undoScenario();
      await tester.pumpAndSettle();
      expect(
        identical(createController.state.draft.scenarioData, draftBeforeApply),
        isTrue,
      );
      createController.redoScenario();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(
        createController.state.draft.scenarioData!.items.single.id,
        itemId,
      );

      final beforeReplace = createController.state.draft.scenarioData!;
      final undoCountBeforeReplace =
          createController.state.scenarioUndoStack.length;
      final savesBeforeReplace = createRepository.saveCount;
      transitRepository.currentOption = _option(
        date: date,
        departure: 11 * 3600,
        arrival: 12 * 3600 + 30 * 60,
        sha: 'b' * 64,
      );

      await _tapVisible(
        tester,
        find.byKey(ValueKey<String>('scenario-transit-recheck-$itemId')),
      );
      expect(
        createController.state.draft.scenarioData!.revision,
        beforeReplace.revision,
      );
      expect(
        find.byKey(const ValueKey<String>('scenario-transit-diff-departure')),
        findsOneWidget,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('scenario-transit-confirm-replace')),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      final replaced = createController.state.draft.scenarioData!;
      final source =
          replaced.items.single.source as ScenarioPlannedTransportSourceDraft;
      expect(replaced.items.single.id, itemId);
      expect(replaced.days.single.itemIds, <String>[itemId]);
      expect(source.scheduleSnapshot?.feedSha256, 'b' * 64);
      expect(source.scheduleSnapshot?.plannedDeparture?.hhmm, '11:00');
      expect(
        createController.state.scenarioUndoStack,
        hasLength(undoCountBeforeReplace + 1),
      );
      expect(createRepository.saveCount, savesBeforeReplace + 1);
      createController.undoScenario();
      expect(
        identical(createController.state.draft.scenarioData, beforeReplace),
        isTrue,
      );
      createController.redoScenario();
      expect(
        identical(createController.state.draft.scenarioData, replaced),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await createController.goToScenarioStep(2);
      await tester.pumpAndSettle();
      expect(find.text('Provider: Provider A'), findsOneWidget);
      expect(find.text('Licence: CC0 1.0'), findsOneWidget);
      expect(find.text('Service date: ${date.iso8601}'), findsOneWidget);
      expect(
        find.text('Feed retrieved: 2026-08-03T08:00:00.000Z'),
        findsOneWidget,
      );
      expect(find.text('Feed SHA-256: ${'b' * 64}'), findsOneWidget);
      expect(find.textContaining('Planned schedule · not live'), findsWidgets);
      expect(
        find.textContaining('Fare, tickets, seats, availability'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ScenarioTransitServiceOption _option({
  required ScenarioLocalDateDraft date,
  int departure = 10 * 3600,
  int arrival = 11 * 3600,
  String? sha,
}) => ScenarioTransitServiceOption(
  providerCode: 'provider-a',
  serviceDate: ScenarioTransitLocalDate(date.year, date.month, date.day),
  tripId: 'trip-1',
  routeId: 'route-1',
  serviceId: 'weekday',
  mode: ScenarioTransitMode.train,
  origin: const ScenarioTransitStop(
    providerCode: 'provider-a',
    id: 'origin',
    name: 'Riga Central',
    latitude: 56.9463,
    longitude: 24.1204,
  ),
  destination: const ScenarioTransitStop(
    providerCode: 'provider-a',
    id: 'destination',
    name: 'Sigulda',
    latitude: 57.1537,
    longitude: 24.8538,
  ),
  departure: ScenarioTransitTime(departure),
  arrival: ScenarioTransitTime(arrival),
  manifest: ScenarioTransitFeedManifest(
    providerCode: 'provider-a',
    providerDisplayName: 'Provider A',
    licenseName: 'CC0 1.0',
    sourceUrl: 'https://example.test/a.zip',
    retrievedAtUtc: DateTime.utc(2026, 8, 3, 8),
    sha256: sha ?? 'a' * 64,
    freshness: ScenarioTransitFreshness.current,
  ),
  agencyName: 'Vivi',
  routeLabel: 'Riga–Sigulda',
);

class _TransitRepository implements ScenarioTransitScheduleRepository {
  ScenarioTransitServiceOption? currentOption;

  @override
  List<ScenarioTransitProviderDescriptor> get providers =>
      const <ScenarioTransitProviderDescriptor>[
        ScenarioTransitProviderDescriptor(
          code: 'provider-a',
          displayName: 'Provider A',
          licenseName: 'CC0 1.0',
          sourceUrl: 'https://example.test/a.zip',
          refreshEnabled: true,
        ),
      ];

  @override
  Future<ScenarioTransitCacheInspection> inspectCache(
    String providerCode,
  ) async {
    final manifest = currentOption!.manifest;
    return ScenarioTransitCacheInspection(
      providerCode: providerCode,
      status: ScenarioTransitCacheStatus.current,
      manifest: manifest,
    );
  }

  @override
  Future<ScenarioTransitFeedManifest?> loadLastKnownGood(
    String providerCode,
  ) async => currentOption!.manifest;

  @override
  Future<ScenarioTransitFeedManifest> refreshProvider(
    String providerCode,
  ) async => currentOption!.manifest;

  @override
  Future<ScenarioTransitSearchResult> searchServices(
    ScenarioTransitSearchQuery query,
  ) async => ScenarioTransitSearchResult(
    options: <ScenarioTransitServiceOption>[currentOption!],
    loadedProviders: const <String>{'provider-a'},
    unavailableProviders: const <String>{},
  );

  @override
  Future<List<ScenarioTransitStop>> searchStops({
    required String query,
    Set<String> providerCodes = const <String>{},
    int limit = 20,
  }) async =>
      <ScenarioTransitStop>[currentOption!.origin, currentOption!.destination]
          .where(
            (stop) => stop.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
}

class _CreateRepository implements CreateRepository {
  CreateDraftEntity? stored;
  int saveCount = 0;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    saveCount++;
    stored = draft;
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async => draft;
}

class _Ids implements IdGenerator {
  int _value = 0;

  @override
  String generate() => 'scenario-transit-id-${_value++}';
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
