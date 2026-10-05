import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/session_create_coordinator.dart';
import 'package:recharge/features/create/application/state/create_state.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/materialize_session_schedule_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/find_people_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/place_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/rental_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/session_create_block.dart';

import '../support/event_create_test_support.dart';

/// Stabilization gate: every step of the Place, Find People, Rental and
/// Session Create blocks must lay out at 360 dp wide and 150% text scale
/// without an overflow or layout exception.
void main() {
  const int placeSteps = 3;
  const int findPeopleSteps = 6;
  const int rentalSteps = 8;

  for (int step = 0; step < placeSteps; step++) {
    testWidgets('Place step $step fits 360 dp at 150% text', (tester) async {
      final CreateController controller = await _controller(
        tester,
        CreateObjectType.place,
      );
      await _pump(
        tester,
        controller,
        (CreateState state) => PlaceCreateBlock(
          controller: controller,
          state: state.copyWith(placeStep: step),
          onPublished: () {},
        ),
      );
    });
  }

  for (int step = 0; step < findPeopleSteps; step++) {
    testWidgets('Find People step $step fits 360 dp at 150% text', (
      tester,
    ) async {
      final CreateController controller = await _controller(
        tester,
        CreateObjectType.findPeople,
      );
      await _pump(
        tester,
        controller,
        (CreateState state) => FindPeopleCreateBlock(
          controller: controller,
          state: state.copyWith(findPeopleStep: step),
          onPublished: () {},
        ),
      );
    });
  }

  for (int step = 0; step < rentalSteps; step++) {
    testWidgets('Rental step $step fits 360 dp at 150% text', (tester) async {
      final CreateController controller = await _controller(
        tester,
        CreateObjectType.rental,
      );
      await _pump(
        tester,
        controller,
        (CreateState state) => RentalCreateBlock(
          controller: controller,
          state: state.copyWith(rentalStep: step),
          onPublished: () {},
        ),
      );
    });
  }

  testWidgets('Session block fits 360 dp at 150% text', (tester) async {
    final CreateController controller = await _controller(
      tester,
      CreateObjectType.session,
    );
    await _pump(
      tester,
      controller,
      (CreateState state) => SessionCreateBlock(
        controller: controller,
        state: state,
        onPublished: () {},
      ),
    );
  });
}

Future<CreateController> _controller(
  WidgetTester tester,
  CreateObjectType type,
) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
  final _MemoryRepository repository = _MemoryRepository();
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
  addTearDown(controller.dispose);
  await controller.ensureLoaded(
    userId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'Creator',
  );
  controller.setObjectType(type);
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  CreateController controller,
  Widget Function(CreateState state) block,
) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        );
      },
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            return SingleChildScrollView(child: block(controller.state));
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Flush the autosave timer scheduled by the type selection.
  await tester.pump(const Duration(milliseconds: 800));

  expect(tester.takeException(), isNull);
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
