import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/event_publication_panel.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_event_draft.dart';
import 'support/event_details_harness.dart';
import 'support/stand_backend.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/pages/create_page.dart';
import '../support/event_create_test_support.dart';

/// C3 through the UI: the signed-in user's Create Event draft is published from
/// the default-off test page with the real controller, Create repository,
/// Content/Media adapters and the local demo-recharge stand; staff review is
/// the C2 staff script. The define `RECHARGE_TEST_EVENT_PUBLICATION=true` must
/// come from the gate: the guard is the production one.
///
/// Limits: PC host run (no physical device), Session from the B1-local Auth
/// Emulator path, Media with the existing fake scanner/processor.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late CreateController createController;

  Future<String> pageId() async {
    final manifest = await stand!.manifest();
    return (manifest['contentEvent']! as Map)['pageId']! as String;
  }

  Future<void> boot() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final binding = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    final repository = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );
    // The draft the user built in Create, stored by Create's own repository.
    await repository.saveDraft(
      'user-1',
      userEventDraft(
        pageId: await pageId(),
        coverPath: '',
        localId: 'loc_c3_ui_${const Uuid().v4()}',
        title: 'Event template baseline',
      ),
    );
    createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: SpyAnalytics(),
      eventCreateCoordinator: createTestEventCoordinator(),
      runtimeDefaults: const CreateRuntimeDefaults(
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      ),
    );
    await createController.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    final sessions = FileSessionStore(File('${temp.path}/session.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: const FixedInstallationId('c3-ui-installation-creator'),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    sl
      ..registerSingleton<BookingBackendBindingController>(binding)
      ..registerSingleton<EventPublicationTestEntryGuard>(
        EventPublicationTestEntryGuard.fromEnvironment(binding),
      )
      ..registerSingleton<BookingSupportDirectoryProvider>(
        () async => Directory('${temp.path}/support').create(recursive: true),
      )
      ..registerSingleton<CreateRepository>(repository)
      ..registerLazySingletonAsync<BookingTransportRuntime>(
        () async => runtime,
      );
    if (await sessions.read() == null) {
      try {
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
      } on BookingCallableFailure catch (error) {
        fail('establish failed with ${error.code}');
      }
    }
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
    final status = find.byKey(const Key('event-publication-status'));
    final message = find.byKey(const Key('event-publication-message'));
    String text(Finder f) =>
        f.evaluate().isEmpty ? '' : (f.evaluate().first.widget as Text).data!;
    fail(
      'timed out waiting for $finder; status="${text(status)}" '
      'message="${text(message)}"',
    );
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byWidgetPredicate(
      (widget) =>
          widget.key == Key(key) &&
          widget is ButtonStyleButton &&
          widget.onPressed != null,
    );
    await waitFor(tester, finder);
    await tester.tap(finder);
  }

  Finder statusText(String fragment) => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.key == const Key('event-publication-status') &&
        (widget.data ?? '').contains(fragment),
  );

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('c3-ui-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  testWidgets(
    'the user publishes their Create Event draft from the test page',
    (WidgetTester tester) async {
      await tester.runAsync(boot);
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final auth = await tester.runAsync(signedInAuthController);
      // The route is guarded by the same guard that gates every command.
      final router = GoRouter(
        initialLocation: '/create',
        routes: <RouteBase>[
          GoRoute(
            path: '/create',
            builder: (context, state) => const CreatePage(),
          ),
          GoRoute(
            path: '/test/event-publication',
            redirect: (context, state) => eventPublicationTestEntryRedirect(
              sl<EventPublicationTestEntryGuard>(),
              fallback: '/blocked',
            ),
            builder: (context, state) => const EventPublicationPage(),
          ),
          GoRoute(
            path: '/blocked',
            builder: (context, state) => const Text('blocked'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authControllerProvider.overrideWith((ref) => auth!),
            createControllerProvider.overrideWith((ref) => createController),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await waitFor(tester, field('event-title'));
      await tester.enterText(field('event-title'), 'Clay evening (UI path)');
      await tester.enterText(
        field('event-short-description'),
        'A ceramic workshop created through the real Event form.',
      );
      await tester.ensureVisible(field('event-cover'));
      await tester.enterText(field('event-cover'), cover.path);
      await tester.ensureVisible(find.text('Save draft'));
      await tester.tap(find.text('Save draft'));
      await waitFor(tester, find.text('Saved'));
      final stored = await tester.runAsync(
        () => sl<CreateRepository>().loadDraft('user-1'),
      );
      expect(stored!.title, 'Clay evening (UI path)');
      expect(stored.media.coverImage, cover.path);
      // Continue the same saved form draft through the existing server panel.
      // Test harness route transition; production navigation is not claimed.
      router.go('/test/event-publication');
      await waitFor(tester, find.text('Clay evening (UI path)'));

      await tapKey(tester, 'event-publication-save');
      await waitFor(tester, statusText('review: draft'));
      await tapKey(tester, 'event-publication-cover');
      await waitFor(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is ButtonStyleButton &&
              widget.key == const Key('event-publication-submit') &&
              widget.onPressed != null,
        ),
      );
      expect(find.byKey(const Key('event-publication-message')), findsNothing);
      await tapKey(tester, 'event-publication-submit');
      await waitFor(tester, statusText('review: under_review'));

      // Staff review through the C2 staff script, for exactly this object.
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            (widget.key as ValueKey<String>?)?.value.startsWith(
                  'event-publication-object-',
                ) ==
                true,
      );
      final contentId = (tester.widget<ListTile>(tile).key! as ValueKey<String>)
          .value
          .substring('event-publication-object-'.length);
      final queue = await tester.runAsync(
        () => stand!.moderate(<String>['queue']),
      );
      final pending = ((queue!.json['data']! as Map)['pending']! as List)
          .cast<Map<Object?, Object?>>()
          .singleWhere((item) => item['contentId'] == contentId);
      final approved = await tester.runAsync(
        () => stand!.moderate(<String>[
          'approve',
          pending['submissionId']! as String,
          '--reason',
          'c3 UI: approved',
        ]),
      );
      expect(approved!.exitCode, 0, reason: '${approved.json}');

      await tapKey(tester, 'event-publication-refresh');
      await waitFor(tester, statusText('approved_for_publication'));
      await tapKey(tester, 'event-publication-publish');
      await waitFor(tester, statusText('visibility: visible'));
      expect(
        find.byKey(const Key('event-publication-revision')),
        findsOneWidget,
      );

      await tapKey(tester, 'event-publication-hide');
      await waitFor(tester, statusText('visibility: withdrawn'));
      expect(
        find.descendant(of: tile, matching: find.textContaining('withdrawn')),
        findsOneWidget,
      );
    },
    skip: stand == null || !eventPublicationTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
