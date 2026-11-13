import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/class_workshop_publication_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/class_workshop_publication_panel.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/class_workshop_create_coordinator.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/event_timezone_repository.dart';
import 'package:recharge/features/create/domain/usecases/build_class_workshop_content_body.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/class_workshop_create_block.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_class_workshop_draft.dart';
import 'support/event_details_harness.dart';
import '../support/event_create_test_support.dart';
import 'support/stand_backend.dart';

/// D3.6 through the UI: the signed-in user completes their Class / Workshop
/// draft in the config-driven Create block (real CreateController and Create
/// repository), then publishes it from the default-off test page with the
/// real controller, Content/Media adapters and the local demo-recharge stand;
/// staff review is the C2 staff script. The define
/// `RECHARGE_TEST_CLASS_WORKSHOP_PUBLICATION=true` must come from the gate.
///
/// Limits: PC host run (no physical device), identity session from the B1-local Auth
/// Emulator path, Media with the existing fake scanner/processor.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late String serverUserId;
  late Directory temp;
  late File cover;
  late List<File> gallery;
  late CreateRepositoryImpl repository;

  Future<void> boot() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await stand!.classWorkshopSeed();
    serverUserId =
        (await stand.classWorkshopManifest())['createdByUserId']! as String;
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
      serverUserId,
      userClassWorkshopDraft(
        userId: serverUserId,
        coverPath: cover.path,
        galleryPaths: gallery.map((file) => file.path).toList(),
        localId: 'loc_d36_ui_${const Uuid().v4()}',
        title: '',
      ).withoutRightsConfirmation(),
    );
    final sessions = FileSessionStore(File('${temp.path}/session.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: const FixedInstallationId('d36-ui-installation-creator'),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    sl
      ..registerSingleton<BookingBackendBindingController>(binding)
      ..registerSingleton<ClassWorkshopPublicationTestEntryGuard>(
        ClassWorkshopPublicationTestEntryGuard.fromEnvironment(binding),
      )
      ..registerSingleton<BookingSupportDirectoryProvider>(
        () async => Directory('${temp.path}/support').create(recursive: true),
      )
      ..registerSingleton<CreateRuntimeDefaults>(
        const CreateRuntimeDefaults(
          marketCityId: 'riga',
          timezone: 'Europe/Riga',
          country: 'LV',
          city: 'Riga',
          currency: 'EUR',
        ),
      )
      ..registerSingleton<CreateRepository>(repository)
      ..registerSingleton<EventTimezoneRepository>(
        EventTimezoneRepositoryImpl(),
      )
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
    final status = find.byKey(const Key('class-workshop-publication-status'));
    final message = find.byKey(const Key('class-workshop-publication-message'));
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
        widget.key == const Key('class-workshop-publication-status') &&
        (widget.data ?? '').contains(fragment),
  );

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('d36-ui-');
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
    'the user completes the Class draft in the Create block and publishes it',
    (WidgetTester tester) async {
      await tester.runAsync(boot);
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final auth = await tester.runAsync(
        () => classWorkshopStandAuth(serverUserId),
      );

      // 1. The config-driven Create block with the real CreateController.
      final create = CreateController(
        loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
        saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
        publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
        analyticsService: _NoopAnalytics(),
        eventCreateCoordinator: createTestEventCoordinator(),
        classWorkshopCreateCoordinator: ClassWorkshopCreateCoordinator(
          mapper: ClassWorkshopContentBodyMapper(EventTimezoneRepositoryImpl()),
        ),
        runtimeDefaults: sl<CreateRuntimeDefaults>(),
      );
      await tester.runAsync(
        () => create.ensureLoaded(
          userId: serverUserId,
          organizerEmail: 'creator@example.org',
          organizerName: 'Creator',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: create,
              builder: (context, _) => SingleChildScrollView(
                child: ClassWorkshopCreateBlock(
                  controller: create,
                  state: create.state,
                  onPublished: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('class-workshop-issue-title')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('class-workshop-title')),
        'Kronvalda pottery (UI path)',
      );
      await tester.tap(find.byKey(const Key('class-workshop-rights')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('class-workshop-issue-title')), findsNothing);
      expect(find.byKey(const Key('class-workshop-issue-media')), findsNothing);
      await tester.runAsync(create.saveDraft);
      await tester.pumpWidget(const SizedBox.shrink());
      create.dispose();

      // 2. The default-off publication page for that same stored draft.
      // The route is guarded by the same guard that gates every command.
      final router = GoRouter(
        initialLocation: '/test/class-workshop-publication',
        routes: <RouteBase>[
          GoRoute(
            path: '/test/class-workshop-publication',
            redirect: (context, state) =>
                classWorkshopPublicationTestEntryRedirect(
                  sl<ClassWorkshopPublicationTestEntryGuard>(),
                  fallback: '/blocked',
                ),
            builder: (context, state) => const ClassWorkshopPublicationPage(),
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
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await waitFor(tester, find.text('Kronvalda pottery (UI path)'));

      await tapKey(tester, 'class-workshop-publication-save');
      await waitFor(tester, statusText('Review: draft'));
      await tapKey(tester, 'class-workshop-publication-media-upload');
      await waitFor(tester, find.text('Media uploaded: 3'));
      expect(
        find.byKey(const Key('class-workshop-publication-message')),
        findsNothing,
      );
      await tapKey(tester, 'class-workshop-publication-submit');
      await waitFor(tester, statusText('Review: under review'));

      // Staff review through the C2 staff script, for exactly this object.
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            (widget.key as ValueKey<String>?)?.value.startsWith(
                  'class-workshop-publication-object-',
                ) ==
                true,
      );
      final contentId = (tester.widget<ListTile>(tile).key! as ValueKey<String>)
          .value
          .substring('class-workshop-publication-object-'.length);
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
          'd3.6 UI: approved',
        ]),
      );
      expect(approved!.exitCode, 0, reason: '${approved.json}');

      await tapKey(tester, 'class-workshop-publication-refresh');
      await waitFor(tester, statusText('Review: approved'));
      await tapKey(tester, 'class-workshop-publication-publish');
      await waitFor(tester, statusText('visibility: visible'));
      expect(
        find.byKey(const Key('class-workshop-publication-revision')),
        findsOneWidget,
      );

      await tapKey(tester, 'class-workshop-publication-hide');
      await waitFor(tester, statusText('visibility: hidden'));
      expect(
        find.descendant(of: tile, matching: find.textContaining('hidden')),
        findsOneWidget,
      );
    },
    skip: stand == null || !classWorkshopPublicationTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<AuthController> classWorkshopStandAuth(String userId) async {
  final AuthController controller = AuthController(
    signInUseCase: SignInUseCase(_ClassWorkshopAuthRepository(userId)),
    restoreSessionUseCase: RestoreSessionUseCase(
      _ClassWorkshopAuthRepository(userId),
    ),
    signOutUseCase: SignOutUseCase(_ClassWorkshopAuthRepository(userId)),
    getCurrentUserUseCase: GetCurrentUserUseCase(
      _ClassWorkshopAuthRepository(userId),
    ),
    analyticsService: SpyAnalytics(),
  );
  await controller.signIn(
    email: 'user@example.com',
    password: 'password123',
    sourceScreen: 'test',
    sourceAction: 'seed',
  );
  return controller;
}

final class _ClassWorkshopAuthRepository implements AuthRepository {
  _ClassWorkshopAuthRepository(this.userId);
  final String userId;
  @override
  Future<AuthUserEntity?> getCurrentUser() async => null;

  @override
  Future<AuthResultEntity?> restoreSession() async => null;

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async => AuthResultEntity(
    session: AuthSessionEntity(
      accessToken: 'access',
      refreshToken: 'refresh',
      sessionId: 'session',
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    ),
    user: AuthUserEntity(
      id: userId,
      email: 'user@example.com',
      role: 'user',
      capabilities: <String>['discover.read', 'favorites.write'],
      profileStatus: 'active',
    ),
  );

  @override
  Future<void> signOut() async {}
}

class _NoopAnalytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
