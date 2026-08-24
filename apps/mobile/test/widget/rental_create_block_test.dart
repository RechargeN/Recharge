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
import 'package:recharge/features/create/presentation/widgets/rental_create_block.dart';

import '../support/event_create_test_support.dart';
import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets(
    'renders the listing step and advances once required fields are filled',
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
        organizerName: 'Creator',
        capabilities: const <String>['create.rental', 'submit.rental'],
      );
      controller.setObjectType(CreateObjectType.rental);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) {
                return SingleChildScrollView(
                  child: RentalCreateBlock(
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

      expect(find.text('Step 1 of 8'), findsOneWidget);
      expect(find.text('Listing and media'), findsOneWidget);

      controller.updateRentalTitle('Mountain bikes for weekend rides');
      controller.updateRentalShortDescription(
        'Well maintained trail bikes in several sizes, helmets included.',
      );
      controller.updateRentalFullDescription(
        'Full description with more than fifty characters covering the '
        'bikes available for rent, condition and included accessories.',
      );
      controller.confirmRentalCategory();
      await tester.pumpAndSettle();

      final bool advanced = await controller.goToRentalStep(1);
      await tester.pumpAndSettle();

      expect(advanced, isTrue);
      expect(find.text('Step 2 of 8'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
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
