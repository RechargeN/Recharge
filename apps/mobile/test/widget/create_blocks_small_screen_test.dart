import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:recharge/features/create/presentation/widgets/activity_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/event_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/scenario/scenario_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/route/route_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/class_workshop_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/find_people_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/place_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/rental_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/session_create_block.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

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

  // L4.3: the localized Create forms on lv, en and ru at 360 dp with the
  // text at 100% and 200%: no overflow, and the step's main action can be
  // scrolled into view and tapped.
  group('L4.3: Create forms in lv, en and ru at 360 dp', () {
    final Map<
      String,
      (
        CreateObjectType,
        int,
        Widget Function(CreateController, CreateState, int),
      )
    >
    forms =
        <
          String,
          (
            CreateObjectType,
            int,
            Widget Function(CreateController, CreateState, int),
          )
        >{
          'Place': (
            CreateObjectType.place,
            placeSteps,
            (c, s, step) => PlaceCreateBlock(
              controller: c,
              state: s.copyWith(placeStep: step),
              onPublished: () {},
            ),
          ),
          'Event': (
            CreateObjectType.event,
            5,
            (c, s, step) => EventCreateBlock(
              controller: c,
              state: s.copyWith(eventStep: step),
              taxonomySection: const SizedBox.shrink(),
              onPublished: () {},
            ),
          ),
          'Activity': (
            CreateObjectType.activity,
            4,
            (c, s, step) => ActivityCreateBlock(
              controller: c,
              state: s.copyWith(activityStep: step),
              onPublished: () {},
            ),
          ),
          'Rental': (
            CreateObjectType.rental,
            rentalSteps,
            (c, s, step) => RentalCreateBlock(
              controller: c,
              state: s.copyWith(rentalStep: step),
              onPublished: () {},
            ),
          ),
        };
    // L4.4: the forms deferred in R1.
    forms.addAll(<
      String,
      (
        CreateObjectType,
        int,
        Widget Function(CreateController, CreateState, int),
      )
    >{
      'Find People': (
        CreateObjectType.findPeople,
        findPeopleSteps,
        (c, s, step) => FindPeopleCreateBlock(
          controller: c,
          state: s.copyWith(findPeopleStep: step),
          onPublished: () {},
        ),
      ),
      'Session': (
        CreateObjectType.session,
        1,
        (c, s, step) =>
            SessionCreateBlock(controller: c, state: s, onPublished: () {}),
      ),
      'Class / Workshop': (
        CreateObjectType.classWorkshop,
        1,
        (c, s, step) => ClassWorkshopCreateBlock(
          controller: c,
          state: s,
          onPublished: () {},
        ),
      ),
      'Route': (
        CreateObjectType.route,
        1,
        (c, s, step) =>
            RouteCreateBlock(controller: c, state: s, onPublished: () {}),
      ),
      'Scenario': (
        CreateObjectType.scenario,
        3,
        (c, s, step) => ScenarioCreateBlock(
          controller: c,
          state: s.copyWith(scenarioStep: step),
        ),
      ),
    });
    for (final String language in const <String>['en', 'lv', 'ru']) {
      for (final double scale in const <double>[1, 2]) {
        for (final MapEntry<
              String,
              (
                CreateObjectType,
                int,
                Widget Function(CreateController, CreateState, int),
              )
            >
            form
            in forms.entries) {
          for (int step = 0; step < form.value.$2; step++) {
            testWidgets('${form.key} step $step: $language at ${scale}x', (
              tester,
            ) async {
              final CreateController controller = await _controller(
                tester,
                form.value.$1,
              );
              await _pumpLocalized(
                tester,
                controller,
                (CreateState state) => form.value.$3(controller, state, step),
                Locale(language),
                scale,
              );
              final Finder actions = find.byWidgetPredicate(
                (Widget widget) =>
                    widget is FilledButton || widget is ElevatedButton,
              );
              if (actions.evaluate().isNotEmpty) {
                await tester.ensureVisible(actions.last);
                await tester.pumpAndSettle();
                expect(actions.last.hitTestable(), findsOneWidget);
              }
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });

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
    capabilities: const <String>[
      'create.place',
      'create.rental',
      'create.event',
      'create.collection',
      'create.route',
      'create.social_request',
      'create.session',
      'create.class_workshop',
      'create.scenario',
    ],
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

Future<void> _pumpLocalized(
  WidgetTester tester,
  CreateController controller,
  Widget Function(CreateState state) block,
  Locale locale,
  double scale,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (BuildContext context, Widget? child) {
          final MediaQueryData media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(scale)),
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
    ),
  );
  await tester.pumpAndSettle();
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
