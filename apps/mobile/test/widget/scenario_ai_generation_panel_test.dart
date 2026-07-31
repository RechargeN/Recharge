import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/application/scenario_generation_coordinator.dart';
import 'package:recharge/features/create/data/datasources/catalog_object_picker_mock_datasource.dart';
import 'package:recharge/features/create/data/datasources/scenario_proposal_mock_datasource.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/generate_scenario_proposal_usecase.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/scenario/scenario_create_block.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets(
    'local AI preview is transient and Apply is one undoable mutation',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final _MemoryRepository repository = _MemoryRepository();
      final _SequentialIdGenerator ids = _SequentialIdGenerator();
      final ScenarioCreateCoordinator scenarioCreate =
          ScenarioCreateCoordinator(idGenerator: ids);
      const MockCatalogObjectPickerDataSource catalog =
          MockCatalogObjectPickerDataSource();
      final CreateController controller = CreateController(
        loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
        saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
        publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
        analyticsService: _NoopAnalyticsService(),
        eventCreateCoordinator: createTestEventCoordinator(),
        scenarioCreateCoordinator: scenarioCreate,
        scenarioGenerationCoordinator: ScenarioGenerationCoordinator(
          generateProposal: GenerateScenarioProposalUseCase(
            MockScenarioProposalDataSource(catalog: catalog),
          ),
          scenarioCreateCoordinator: scenarioCreate,
        ),
        catalogObjectPicker: catalog,
        runtimeDefaults: const CreateRuntimeDefaults(
          marketCityId: 'riga',
          timezone: 'Europe/Riga',
          country: 'LV',
          city: 'Riga',
          currency: 'EUR',
        ),
      );
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Planner',
      );
      controller.setObjectType(CreateObjectType.scenario);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) =>
                  SingleChildScrollView(
                    child: ScenarioCreateBlock(
                      controller: controller,
                      state: controller.state,
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Build with AI'), findsOneWidget);
      expect(find.text('Local demo'), findsOneWidget);
      final int sourceRevision = controller.state.draft.scenarioData!.revision;
      final sourceItems = List.of(controller.state.draft.scenarioData!.items);
      final int savesBeforeGeneration = repository.saveCount;

      await tester.enterText(
        find.byKey(const ValueKey<String>('scenario-generation-prompt')),
        'A calm cultural afternoon with a walk and dinner',
      );
      final Finder generate = find.byKey(
        const ValueKey<String>('generate-scenario-preview'),
      );
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('scenario-generation-preview')),
        findsOneWidget,
      );
      expect(find.text('Catalog snapshot'), findsWidgets);
      expect(find.text('Still unverified'), findsOneWidget);
      expect(controller.state.draft.scenarioData!.revision, sourceRevision);
      expect(controller.state.draft.scenarioData!.items, sourceItems);
      expect(controller.state.scenarioUndoStack, isEmpty);
      expect(repository.saveCount, savesBeforeGeneration);

      final Finder apply = find.byKey(
        const ValueKey<String>('apply-scenario-generation'),
      );
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pump();

      expect(controller.state.draft.scenarioData!.items, isNotEmpty);
      expect(controller.state.scenarioUndoStack, hasLength(1));
      expect(controller.state.scenarioGenerationPreview, isNull);

      controller.undoScenario();
      await tester.pump();
      expect(controller.state.draft.scenarioData!.items, sourceItems);

      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      final Finder discard = find.byKey(
        const ValueKey<String>('discard-scenario-generation'),
      );
      await tester.ensureVisible(discard);
      await tester.tap(discard);
      await tester.pump();

      expect(controller.state.scenarioGenerationPreview, isNull);
      expect(controller.state.draft.scenarioData!.items, sourceItems);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SequentialIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => 'scenario-ai-widget-id-${_value++}';
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _MemoryRepository implements CreateRepository {
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
  ) async {
    stored = draft;
    return draft;
  }
}
