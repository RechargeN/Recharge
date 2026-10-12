import 'dart:io';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/pages/create_page.dart';
import 'package:recharge/app/application/active_create_publisher_provider.dart';
import 'package:recharge/app/application/active_creator_verification_provider.dart';
import '../support/event_create_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/activity_publication_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/activity_publication_panel.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_activity_draft.dart';
import 'support/event_details_harness.dart';
import 'support/stand_backend.dart';

/// D3.2 through the UI: the signed-in user's Create Recharge Activity draft is
/// published from the default-off test page with the real controller, Create
/// repository, Content/Media adapters and the local demo-recharge stand; staff
/// review is the C2 staff script. The define
/// `RECHARGE_TEST_ACTIVITY_PUBLICATION=true` must come from the gate: the guard
/// is the production one.
///
/// Limits: PC host run (no physical device), Session from the B1-local Auth
/// Emulator path, Media with the existing fake scanner/processor.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late List<File> gallery;
  late CreateRepository repository;
  late String pageId;

  Future<void> boot() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await stand!.activitySeed();
    pageId = (await stand.activityManifest())['pageId']! as String;
    final binding = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    repository = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );
    // The draft the user built in Create, stored by Create's own repository.
    await repository.saveDraft(
      'user-1',
      userActivityDraft(
        pageId: pageId,
        coverPath: cover.path,
        galleryPaths: gallery.map((file) => file.path).toList(),
        localId: 'loc_d32_ui_${const Uuid().v4()}',
        title: 'Ķemeri bog loop (UI path)',
      ),
    );
    final sessions = FileSessionStore(File('${temp.path}/session.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: const FixedInstallationId('d32-ui-installation-creator'),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    sl
      ..registerSingleton<BookingBackendBindingController>(binding)
      ..registerSingleton<ActivityPublicationTestEntryGuard>(
        ActivityPublicationTestEntryGuard.fromEnvironment(binding),
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
    final status = find.byKey(const Key('activity-publication-status'));
    final message = find.byKey(const Key('activity-publication-message'));
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
        widget.key == const Key('activity-publication-status') &&
        (widget.data ?? '').contains(fragment),
  );

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('d32-ui-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
    gallery = <File>[
      await File(
        'test/fixtures/media/stand_gallery_1.png',
      ).copy('${temp.path}/gallery-1.png'),
      await File(
        'test/fixtures/media/stand_gallery_2.png',
      ).copy('${temp.path}/gallery-2.png'),
    ];
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  testWidgets(
    'the user publishes their Create Activity draft from the test page',
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
        initialLocation: '/test/activity-publication',
        routes: <RouteBase>[
          GoRoute(
            path: '/test/activity-publication',
            redirect: (context, state) => activityPublicationTestEntryRedirect(
              sl<ActivityPublicationTestEntryGuard>(),
              fallback: '/blocked',
            ),
            builder: (context, state) => const ActivityPublicationPage(),
          ),
          GoRoute(
            path: '/create/new/activity',
            builder: (context, state) => CreatePage(
              initialObjectType: CreateObjectType.activity,
              seedParameters: state.uri.queryParameters,
            ),
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
            activeCreatePublisherProvider.overrideWith((ref) => null),
            activeCreatorVerificationProvider.overrideWith((ref) => true),
            createControllerProvider.overrideWith(
              (ref) => CreateController(
                loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
                saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
                publishCreateDraftUseCase: PublishCreateDraftUseCase(
                  repository,
                ),
                analyticsService: ConsoleAnalyticsService(),
                eventCreateCoordinator: createTestEventCoordinator(),
                runtimeDefaults: const CreateRuntimeDefaults(
                  marketCityId: 'riga',
                  timezone: 'Europe/Riga',
                  country: 'LV',
                  city: 'Riga',
                  currency: 'EUR',
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await waitFor(tester, find.text('Ķemeri bog loop (UI path)'));

      await tapKey(tester, 'activity-publication-save');
      await waitFor(tester, statusText('review: draft'));
      await tapKey(tester, 'activity-publication-media-upload');
      await waitFor(tester, find.text('Media uploaded: 3'));
      expect(
        find.byKey(const Key('activity-publication-message')),
        findsNothing,
      );
      await tapKey(tester, 'activity-publication-submit');
      await waitFor(tester, statusText('review: under_review'));

      // Staff review through the C2 staff script, for exactly this object.
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            (widget.key as ValueKey<String>?)?.value.startsWith(
                  'activity-publication-object-',
                ) ==
                true,
      );
      final contentId = (tester.widget<ListTile>(tile).key! as ValueKey<String>)
          .value
          .substring('activity-publication-object-'.length);
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
          'd3.2 UI: approved',
        ]),
      );
      expect(approved!.exitCode, 0, reason: '${approved.json}');

      await tapKey(tester, 'activity-publication-refresh');
      await waitFor(tester, statusText('approved_for_publication'));
      await tapKey(tester, 'activity-publication-publish');
      await waitFor(tester, statusText('visibility: visible'));
      expect(
        find.byKey(const Key('activity-publication-revision')),
        findsOneWidget,
      );

      await tapKey(tester, 'activity-publication-hide');
      await waitFor(tester, statusText('visibility: withdrawn'));
      expect(
        find.descendant(of: tile, matching: find.textContaining('withdrawn')),
        findsOneWidget,
      );
      await tapKey(tester, 'activity-publication-activate');
      await waitFor(tester, statusText('visibility: visible'));
      final originalRevisionText = tester
          .widget<Text>(find.byKey(const Key('activity-publication-revision')))
          .data;
      await tapKey(tester, 'activity-publication-edit');
      await waitFor(tester, find.text('Title'));
      expect(find.textContaining('Editing draft only.'), findsOneWidget);
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Title',
      );
      // Edit the original shared form, then let its existing autosave persist.
      await tester.enterText(titleField, 'Edited bog loop from Create');
      await tester.pump(const Duration(milliseconds: 900));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      final stored = await tester.runAsync(
        () => repository.loadDraft('user-1'),
      );
      expect(stored!.title, 'Edited bog loop from Create');
      for (var step = 0; step < 3; step++) {
        final next = find.text('Save & continue');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.text('Send for review'), findsNothing);
      final returnButton = find.text('Save draft & return');
      await tester.ensureVisible(returnButton);
      await tester.tap(returnButton);
      await waitFor(
        tester,
        find.textContaining('unpublished changes; review required'),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('activity-publication-revision')),
            )
            .data,
        originalRevisionText,
      );
      await tapKey(tester, 'activity-publication-save');
      await tapKey(tester, 'activity-publication-submit');
      await waitFor(tester, statusText('review: under_review'));
      final editedQueue = await tester.runAsync(
        () => stand!.moderate(<String>['queue']),
      );
      final editedPending =
          ((editedQueue!.json['data']! as Map)['pending']! as List)
              .cast<Map<Object?, Object?>>()
              .singleWhere((item) => item['contentId'] == contentId);
      final editedApproved = await tester.runAsync(
        () => stand!.moderate(<String>[
          'approve',
          editedPending['submissionId']! as String,
          '--reason',
          'd3.7 UI: edited Activity approved',
        ]),
      );
      expect(editedApproved!.exitCode, 0, reason: '${editedApproved.json}');
      await tapKey(tester, 'activity-publication-refresh');
      await waitFor(tester, statusText('approved_for_publication'));
      await tapKey(tester, 'activity-publication-publish');
      await waitFor(tester, statusText('review: published'));
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('activity-publication-revision')),
            )
            .data,
        isNot(originalRevisionText),
      );
      expect(
        find.textContaining('unpublished changes; review required'),
        findsNothing,
      );
    },
    skip: stand == null || !activityPublicationTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
