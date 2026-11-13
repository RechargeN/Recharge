import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/application/session_create_coordinator.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/materialize_session_schedule_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../../support/event_create_test_support.dart';

/// Exercises the existing typed block, common controller and persisted draft
/// before the real publication stand continues with that same draft.
Future<void> editAndReloadCreateBlock(
  WidgetTester tester, {
  required CreateRepository repository,
  required String userId,
  required CreateRuntimeDefaults runtimeDefaults,
  required CreateObjectType expectedType,
  required String titleLabel,
  required Widget Function(CreateController controller) block,
}) async {
  CreateController makeController() => CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
    analyticsService: _NoopAnalytics(),
    eventCreateCoordinator: createTestEventCoordinator(),
    // Existing app DI coordinators, including the client-only schedule preview.
    sessionCreateCoordinator: SessionCreateCoordinator(
      materializeSchedule: MaterializeSessionScheduleUseCase(
        EventTimezoneRepositoryImpl(),
      ),
    ),
    scenarioCreateCoordinator: ScenarioCreateCoordinator(
      idGenerator: UuidV4IdGenerator(),
    ),
    runtimeDefaults: runtimeDefaults,
  );

  Future<void> load(CreateController controller) async {
    await tester.runAsync(
      () => controller.ensureLoaded(
        userId: userId,
        organizerEmail: 'creator@example.org',
        organizerName: 'Creator',
      ),
    );
    expect(controller.state.draft.objectType, expectedType);
  }

  Future<void> mount(CreateController controller) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) =>
              SingleChildScrollView(child: block(controller)),
        ),
      ),
    ),
  );

  final first = makeController();
  await load(first);
  final draftId = first.state.draft.id;
  final originalTitle = first.state.draft.title;
  const editedTitle = 'Edited in Create before restart';
  await mount(first);
  // TextFormField delegates to TextField; Find People uses TextField directly.
  final title = find.widgetWithText(TextField, titleLabel);
  expect(title, findsOneWidget);
  await tester.ensureVisible(title);
  await tester.enterText(title, editedTitle);
  await tester.pump();
  expect(first.state.draft.title, editedTitle);
  await tester.runAsync(first.saveDraft);
  expect(
    (await tester.runAsync(() => repository.loadDraft(userId)))!.title,
    editedTitle,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  first.dispose();

  // Recreate the real controller and block rather than reusing in-memory state.
  final restored = makeController();
  await load(restored);
  expect(restored.state.draft.id, draftId);
  expect(restored.state.draft.title, editedTitle);
  await mount(restored);
  await tester.ensureVisible(title);
  await tester.enterText(title, originalTitle);
  await tester.pump();
  await tester.runAsync(restored.saveDraft);
  final saved = (await tester.runAsync(() => repository.loadDraft(userId)))!;
  expect(saved.id, draftId);
  expect(saved.title, originalTitle);
  await tester.pumpWidget(const SizedBox.shrink());
  restored.dispose();
}

class _NoopAnalytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
