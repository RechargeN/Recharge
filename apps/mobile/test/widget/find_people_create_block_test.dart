import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/find_people_create_block.dart';

import '../support/event_create_test_support.dart';
import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets(
    'renders Find People as six sections in shared Create flow',
    (WidgetTester tester) async {
      final _MemoryRepository repository = _MemoryRepository();
      final CreateController controller = CreateController(
        loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
        saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
        publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
        analyticsService: _NoopAnalyticsService(),
        eventCreateCoordinator: createTestEventCoordinator(),
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
        organizerName: 'Host',
        capabilities: const <String>['create.find_people'],
      );
      controller.setObjectType(CreateObjectType.findPeople);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) {
                return SingleChildScrollView(
                  child: FindPeopleCreateBlock(
                    controller: controller,
                    state: controller.state,
                    onPublished: () {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find People · 1/6'), findsOneWidget);
      expect(find.text('1. Activity'), findsOneWidget);
      expect(find.text('2. When'), findsOneWidget);
      expect(find.text('3. Where'), findsOneWidget);
      expect(find.text('4. Group'), findsOneWidget);
      expect(find.text('5. Hosts & access'), findsOneWidget);
      expect(find.text('6. Preview & publish'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Title *'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('find-people-category')),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Weekend tennis practice',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(controller.state.draft.title, 'Weekend tennis practice');
      expect(controller.state.saveStatus.name, 'saved');
      expect(repository.stored?.title, 'Weekend tennis practice');
      expect(controller.state.draft.findPeopleData, isNotNull);
    },
  );
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
