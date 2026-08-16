import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_logistics_draft.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/scenario/scenario_create_block.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets(
    'Scenario Create shows own car and labels planned transport as not live',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final _MemoryRepository repository = _MemoryRepository();
      final CreateController controller = CreateController(
        loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
        saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
        publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
        analyticsService: _NoopAnalyticsService(),
        eventCreateCoordinator: createTestEventCoordinator(),
        scenarioCreateCoordinator: ScenarioCreateCoordinator(
          idGenerator: _SequentialIdGenerator(),
        ),
        runtimeDefaults: const CreateRuntimeDefaults(
          marketCityId: 'latvia',
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

      expect(find.text('How will you travel?'), findsOneWidget);
      expect(find.text('Own car'), findsWidgets);
      expect(find.text('Own car profile'), findsNothing);
      expect(find.text('Consumption'), findsNothing);
      expect(find.text('Fuel price'), findsNothing);
      expect(find.text('Include estimated fuel in budget'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('vehicle-consumption-null')),
        findsNothing,
      );
      expect(
        controller.state.draft.scenarioData!.constraints.primaryTravelMode,
        ScenarioTravelMode.car,
      );

      await controller.goToScenarioStep(1);
      await tester.pumpAndSettle();
      final Finder addTransport = find.byKey(
        const ValueKey<String>('add-planned-transport'),
      );
      await tester.ensureVisible(addTransport);
      await tester.tap(addTransport);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('scenario-transit-choice-official')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('scenario-service-label')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Planned schedule · not live. Recheck the service before travel.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('scenario-service-label')),
        'Train 802',
      );
      final Finder save = find.byKey(
        const ValueKey<String>('save-planned-transport'),
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final source =
          controller.state.draft.scenarioData!.items.single.source
              as ScenarioPlannedTransportSourceDraft;
      expect(source.publicServiceLabel, 'Train 802');
      expect(source.scheduleSnapshot?.providerCode, 'manual');

      await controller.goToScenarioStep(2);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Planned schedule · not live. Recheck departures, delays and cancellations before travel.',
        ),
        findsOneWidget,
      );
      expect(find.text('Entered manually · not verified'), findsOneWidget);
      expect(find.text('Feed SHA-256: unknown'), findsOneWidget);
      expect(
        find.textContaining('Fare, tickets, seats, availability'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _SequentialIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => 'scenario-transport-id-${_value++}';
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _MemoryRepository implements CreateRepository {
  CreateDraftEntity? stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
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
