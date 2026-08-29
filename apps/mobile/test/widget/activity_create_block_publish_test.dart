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
import 'package:recharge/features/create/presentation/widgets/activity_create_block.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets('publish button is present on the final step and does not show a price field', (
    WidgetTester tester,
  ) async {
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
    );
    controller.setObjectType(CreateObjectType.activity);
    controller.updateTitle('Hidden viewpoint');
    controller.updateCoverImage('cover.jpg');
    expect(await controller.goToActivityStep(1), isTrue);

    controller.updateActivityCoordinates(latitude: '56.95', longitude: '24.11');
    controller.confirmActivityPin();
    controller.updateActivityAccessNotes('Gravel path from parking.');
    expect(await controller.goToActivityStep(2), isTrue);

    // 'recharge_walk' (activity's default subcategory) requires the
    // 'difficulty' category criterion (see Task 11 debugging).
    controller.updateCategoryCriterion('difficulty', 'easy');
    expect(await controller.goToActivityStep(3), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? child) {
              return SingleChildScrollView(
                child: ActivityCreateBlock(
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

    expect(find.text('Send for review'), findsOneWidget);
    expect(find.textContaining('Price'), findsNothing);
    expect(find.textContaining('Expected spend'), findsNothing);

    // Flush the 700ms autosave timer so no pending Timer remains at test end.
    await tester.pump(const Duration(milliseconds: 800));
  });
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
