import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/session_create_coordinator.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/materialize_session_schedule_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/session_create_block.dart';

import '../support/event_create_test_support.dart';

CreateController _buildController(CreateRepository repository) {
  final CreateController controller = CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
    analyticsService: _NoopAnalyticsService(),
    eventCreateCoordinator: createTestEventCoordinator(),
    sessionCreateCoordinator: SessionCreateCoordinator(
      materializeSchedule: MaterializeSessionScheduleUseCase(
        EventTimezoneRepositoryImpl(),
      ),
    ),
    runtimeDefaults: const CreateRuntimeDefaults(
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    ),
  );
  return controller;
}

Future<void> _pumpSessionBlock(
  WidgetTester tester,
  CreateController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            return SingleChildScrollView(
              child: SessionCreateBlock(
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
  // Flush the 700ms autosave timer scheduled by setObjectType(session) so no
  // pending Timer remains when the test ends.
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  testWidgets(
    'renders the required blocks and an optional-fields toggle for a fresh Session draft',
    (WidgetTester tester) async {
      final _MemoryRepository repository = _MemoryRepository();
      final CreateController controller = _buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
      );
      controller.setObjectType(CreateObjectType.session);

      await _pumpSessionBlock(tester, controller);

      expect(find.text('What and where'), findsOneWidget);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('Price and booking'), findsOneWidget);
      expect(find.text('Optional — add now or after publishing'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      // Everything not marked "required" stays collapsed by default.
      expect(find.text('Blocked dates'), findsNothing);
    },
  );

  testWidgets(
    'a weekly preset tap materializes offers shown as chips',
    (WidgetTester tester) async {
      final _MemoryRepository repository = _MemoryRepository();
      final CreateController controller = _buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
      );
      controller.setObjectType(CreateObjectType.session);
      controller.confirmSessionTimezone('Europe/Riga');

      await _pumpSessionBlock(tester, controller);

      expect(find.text('Every day 9:00–21:00'), findsOneWidget);
      await tester.ensureVisible(find.text('Every day 9:00–21:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every day 9:00–21:00'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));

      expect(controller.state.draft.sessionData!.schedule.weeklyRules, hasLength(7));
      expect(find.text('Next offers'), findsOneWidget);
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
