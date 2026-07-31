import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/create_template_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/create_template_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/manage_create_template_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/event_template_panel.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets('saves, lists and applies an Event template at 360 dp', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _DraftRepository draftRepository = _DraftRepository();
    final _TemplateRepository templateRepository = _TemplateRepository();
    final CreateController controller = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(draftRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(draftRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(draftRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
      createTemplateRepository: templateRepository,
      manageCreateTemplate: ManageCreateTemplateUseCase(
        _SequentialIdGenerator(),
      ),
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
    );
    controller.updateTitle('Friday meetup');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => EventTemplatePanel(controller: controller),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('save-event-template')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('event-template-name')),
      'Community reusable',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text('1 saved'), findsOneWidget);
    expect(find.textContaining('Community reusable'), findsWidgets);
    final String sourceId = controller.state.draft.id;

    await tester.tap(find.byKey(const Key('open-event-templates')));
    await tester.pumpAndSettle();
    expect(find.text('Your Event templates'), findsOneWidget);
    expect(find.text('Community reusable'), findsOneWidget);
    await tester.tap(find.text('Community reusable'));
    await tester.pumpAndSettle();

    expect(controller.state.draft.id, isNot(sourceId));
    expect(controller.state.draft.title, 'Friday meetup');
    expect(controller.lastEventTemplate?.name, 'Community reusable');

    final String appliedId = controller.state.draft.id;
    await controller.startAnotherEvent(
      organizerId: 'user-1',
      organizerEmail: 'fresh@example.com',
      organizerName: 'Fresh host',
    );

    expect(controller.state.draft.id, isNot(appliedId));
    expect(controller.state.draft.title, 'Friday meetup');
    expect(controller.state.draft.organizerEmail, 'fresh@example.com');
  });
}

class _DraftRepository implements CreateRepository {
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
  ) async => draft;
}

class _TemplateRepository implements CreateTemplateRepository {
  final List<CreateTemplateEntity> templates = <CreateTemplateEntity>[];

  @override
  Future<void> deleteTemplate({
    required String userId,
    required String templateId,
  }) async {
    templates.removeWhere(
      (CreateTemplateEntity item) =>
          item.ownerUserId == userId && item.id == templateId,
    );
  }

  @override
  Future<List<CreateTemplateEntity>> listTemplates({
    required String userId,
    required CreateObjectType objectType,
  }) async {
    return templates
        .where(
          (CreateTemplateEntity item) =>
              item.ownerUserId == userId && item.objectType == objectType,
        )
        .toList(growable: false);
  }

  @override
  Future<void> upsertTemplate({
    required String userId,
    required CreateTemplateEntity template,
  }) async {
    templates.removeWhere(
      (CreateTemplateEntity item) => item.id == template.id,
    );
    templates.insert(0, template);
  }
}

class _SequentialIdGenerator implements IdGenerator {
  int next = 0;

  @override
  String generate() => 'template-${next++}';
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
