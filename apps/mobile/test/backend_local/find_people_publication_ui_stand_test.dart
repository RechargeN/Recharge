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
import 'package:recharge/app/di/find_people_publication_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/find_people_publication_panel.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_find_people_draft.dart';
import 'support/event_details_harness.dart';
import 'support/stand_backend.dart';

/// D3.7 through the UI: the signed-in user's Create Find People draft is
/// published from the default-off test page with the real controller, Create
/// repository, Content and consent adapters and the local demo-recharge stand;
/// consent is the user's explicit tap; staff review is the C2 staff script.
/// The define `RECHARGE_TEST_FIND_PEOPLE_PUBLICATION=true` must come from the
/// gate: the guard is the production one.
///
/// Limits: PC host run (no physical device), Session from the B1-local Auth
/// Emulator path, synthetic 18+ attestation from the stand seed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late String serverUserId;
  late Directory temp;

  Future<void> boot() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await stand!.findPeopleSeed();
    serverUserId =
        (await stand.findPeopleManifest())['createdByUserId']! as String;
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
      serverUserId,
      userFindPeopleDraft(
        userId: serverUserId,
        localId: 'loc_d37_ui_${const Uuid().v4()}',
        title: 'Morning run (UI path)',
      ),
    );
    final sessions = FileSessionStore(File('${temp.path}/session.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: const FixedInstallationId('d37-ui-installation-creator'),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    sl
      ..registerSingleton<BookingBackendBindingController>(binding)
      ..registerSingleton<FindPeoplePublicationTestEntryGuard>(
        FindPeoplePublicationTestEntryGuard.fromEnvironment(binding),
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
    final status = find.byKey(const Key('find-people-publication-status'));
    final message = find.byKey(const Key('find-people-publication-message'));
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
        widget.key == const Key('find-people-publication-status') &&
        (widget.data ?? '').contains(fragment),
  );

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('d37-ui-');
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  testWidgets(
    'the user publishes their Create Find People draft with explicit consent',
    (WidgetTester tester) async {
      await tester.runAsync(boot);
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final auth = await tester.runAsync(
        () => findPeopleStandAuth(serverUserId),
      );
      // The route is guarded by the same guard that gates every command.
      final router = GoRouter(
        initialLocation: '/test/find-people-publication',
        routes: <RouteBase>[
          GoRoute(
            path: '/test/find-people-publication',
            redirect: (context, state) =>
                findPeoplePublicationTestEntryRedirect(
                  sl<FindPeoplePublicationTestEntryGuard>(),
                  fallback: '/blocked',
                ),
            builder: (context, state) => const FindPeoplePublicationPage(),
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
      await waitFor(tester, find.text('Morning run (UI path)'));

      await tapKey(tester, 'find-people-publication-save');
      await waitFor(tester, statusText('review: draft'));
      expect(
        find.byKey(const Key('find-people-publication-message')),
        findsNothing,
      );
      // Saving is not consent: Submit stays disabled until the explicit tap.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key == const Key('find-people-publication-submit') &&
              widget is ButtonStyleButton &&
              widget.onPressed == null,
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'find-people-publication-consent-grant');
      await waitFor(tester, find.textContaining('consent: active'));
      await tapKey(tester, 'find-people-publication-submit');
      await waitFor(tester, statusText('review: under_review'));

      // Staff review through the C2 staff script, for exactly this object.
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            (widget.key as ValueKey<String>?)?.value.startsWith(
                  'find-people-publication-object-',
                ) ==
                true,
      );
      final contentId = (tester.widget<ListTile>(tile).key! as ValueKey<String>)
          .value
          .substring('find-people-publication-object-'.length);
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
          'd3.7 UI: approved',
        ]),
      );
      expect(approved!.exitCode, 0, reason: '${approved.json}');

      await tapKey(tester, 'find-people-publication-refresh');
      await waitFor(tester, statusText('approved_for_publication'));
      await tapKey(tester, 'find-people-publication-publish');
      await waitFor(tester, statusText('visibility: visible'));
      expect(
        find.byKey(const Key('find-people-publication-revision')),
        findsOneWidget,
      );

      await tapKey(tester, 'find-people-publication-hide');
      await waitFor(tester, statusText('visibility: withdrawn'));
      expect(
        find.descendant(of: tile, matching: find.textContaining('withdrawn')),
        findsOneWidget,
      );
    },
    skip: stand == null || !findPeoplePublicationTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<AuthController> findPeopleStandAuth(String userId) async {
  final AuthController controller = AuthController(
    signInUseCase: SignInUseCase(_FindPeopleAuthRepository(userId)),
    restoreSessionUseCase: RestoreSessionUseCase(
      _FindPeopleAuthRepository(userId),
    ),
    signOutUseCase: SignOutUseCase(_FindPeopleAuthRepository(userId)),
    getCurrentUserUseCase: GetCurrentUserUseCase(
      _FindPeopleAuthRepository(userId),
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

final class _FindPeopleAuthRepository implements AuthRepository {
  _FindPeopleAuthRepository(this.userId);
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
