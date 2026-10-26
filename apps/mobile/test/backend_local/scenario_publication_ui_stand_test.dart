import 'package:recharge/features/create/presentation/widgets/scenario/scenario_create_block.dart';
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
import 'package:recharge/app/di/scenario_publication_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/scenario_publication_panel.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_scenario_planning_gateway.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/scenario_sync_client.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/repositories/create_draft_collection_repository.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_scenario_draft.dart';
import 'session_publication_ui_stand_test.dart' show sessionStandAuth;
import 'support/create_block_stand_harness.dart';
import 'support/stand_backend.dart';

/// I3 through the UI: the signed-in Creator's Create Scenario is saved on the
/// server through the I2 sync client, then pinned, bound with a cover,
/// submitted, approved by the C2 staff script, published, shared unlisted,
/// revoked and hidden from the default-off test page, with the real controller,
/// Planning/Content/Media adapters and the local demo-recharge stand. The
/// define `RECHARGE_TEST_SCENARIO_PUBLICATION=true` comes from the gate.
///
/// Limits: PC host run (no physical device), Session from the B1-local Auth
/// Emulator path, Media with the existing fake scanner/processor.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late String serverUserId;
  late Directory temp;
  late File cover;
  late CreateDraftEntity draft;
  late BookingTransportRuntime runtime;

  Future<void> boot() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await stand!.scenarioSeed();
    serverUserId =
        (await stand.scenarioManifest())['publisherUserId']! as String;
    final binding = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    final repository = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );
    draft = userScenarioDraft(
      userId: serverUserId,
      coverPath: cover.path,
      title: 'Riga old town (UI path)',
    );
    await repository.saveDraft(serverUserId, draft);
    final sessions = FileSessionStore(File('${temp.path}/session.json'));
    runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: const FixedInstallationId('i3-ui-installation-creator'),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    sl
      ..registerSingleton<BookingBackendBindingController>(binding)
      ..registerSingleton<ScenarioPublicationTestEntryGuard>(
        ScenarioPublicationTestEntryGuard.fromEnvironment(binding),
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
    // I2: the Scenario Builder's draft is saved on the server through the
    // existing conditional-save port, exactly as Create persists it.
    final sync = ScenarioSyncClient(
      invoke: (String surface, Map<String, Object?> request) =>
          runtime.port!.invoke(surface, request),
      storage: const FlutterSecureStorage(),
      installationId: 'i3-ui-installation-creator',
      currentActor: () => serverUserId,
    );
    final saved = await sync.saveIfRevision(
      ownerId: serverUserId,
      draft: draft,
      expectedScenarioRevision: 0,
      idempotencyKey: const Uuid().v4(),
    );
    expect(saved.status, CreateDraftCollectionSaveStatus.saved);
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
    String text(String key) {
      final Finder f = find.byKey(Key(key));
      return f.evaluate().isEmpty
          ? ''
          : (f.evaluate().first.widget as Text).data!;
    }

    fail(
      'timed out waiting for $finder; status="${text('scenario-publication-status')}" '
      'message="${text('scenario-publication-message')}"',
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
        widget.key == const Key('scenario-publication-status') &&
        (widget.data ?? '').contains(fragment),
  );

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('i3-ui-');
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
    'the Creator edits and restores the Create Scenario block before publishing and sharing',
    (WidgetTester tester) async {
      await tester.runAsync(boot);
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final auth = await tester.runAsync(() => sessionStandAuth(serverUserId));
      await editAndReloadCreateBlock(
        tester,
        repository: sl<CreateRepository>(),
        userId: serverUserId,
        runtimeDefaults: sl<CreateRuntimeDefaults>(),
        expectedType: CreateObjectType.scenario,
        titleLabel: 'Scenario title *',
        block: (create) =>
            ScenarioCreateBlock(controller: create, state: create.state),
      );

      final router = GoRouter(
        initialLocation: '/test/scenario-publication',
        routes: <RouteBase>[
          GoRoute(
            path: '/test/scenario-publication',
            redirect: (context, state) => scenarioPublicationTestEntryRedirect(
              sl<ScenarioPublicationTestEntryGuard>(),
              fallback: '/blocked',
            ),
            builder: (context, state) => const ScenarioPublicationPage(),
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
      await waitFor(tester, find.text('Riga old town (UI path)'));
      await waitFor(tester, find.text('Server revision 1'));

      await tapKey(tester, 'scenario-publication-prepare');
      await waitFor(tester, statusText('review: draft'));
      await tester.tap(find.byKey(const Key('scenario-publication-rights')));
      await tapKey(tester, 'scenario-publication-cover');
      await tapKey(tester, 'scenario-publication-submit');
      await waitFor(tester, statusText('review: under_review'));
      expect(
        find.byKey(const Key('scenario-publication-message')),
        findsNothing,
      );

      // Staff review through the C2 staff script, for exactly this Scenario.
      final queue = await tester.runAsync(
        () => stand!.moderate(<String>['queue']),
      );
      final pending = ((queue!.json['data']! as Map)['pending']! as List)
          .cast<Map<Object?, Object?>>()
          .singleWhere((item) => item['contentId'] == draft.id);
      final approved = await tester.runAsync(
        () => stand!.moderate(<String>[
          'approve',
          pending['submissionId']! as String,
          '--reason',
          'i3 UI: approved',
        ]),
      );
      expect(approved!.exitCode, 0, reason: '${approved.json}');

      await tapKey(tester, 'scenario-publication-refresh');
      await waitFor(tester, statusText('approved_for_publication'));
      await tapKey(tester, 'scenario-publication-publish');
      await waitFor(tester, statusText('visibility: visible'));

      // Unlisted: the token is shown once and any signed-in reader can open it.
      await tapKey(tester, 'scenario-publication-share-link');
      await waitFor(tester, find.textContaining('Unlisted link until'));
      final String shown =
          (tester
              .widget<SelectableText>(
                find.byKey(const Key('scenario-publication-share')),
              )
              .data ??
          '');
      final String token = shown.split(': ').last;
      final gateway = FunctionsScenarioPlanningGateway(
        port: BookingPortContentAdapter(runtime.port!),
        gate: sl<ScenarioPublicationTestEntryGuard>(),
        accountId: serverUserId,
      );
      final Map<String, Object?>? share = await tester.runAsync(
        () => gateway.resolveShare(token),
      );
      final distribution = share!['distribution']! as Map<Object?, Object?>;
      expect(distribution['title'], 'Riga old town (UI path)');
      expect(share.toString().contains('PRIVATE'), isFalse);

      await tapKey(tester, 'scenario-publication-unshare');
      for (int i = 0; i < 300; i += 1) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find
            .byKey(const Key('scenario-publication-share'))
            .evaluate()
            .isEmpty) {
          break;
        }
      }
      expect(find.byKey(const Key('scenario-publication-share')), findsNothing);
      Object? refusal;
      await tester.runAsync(() async {
        try {
          await gateway.resolveShare(token);
        } on EventPublicationRejected catch (error) {
          refusal = error.code;
        }
      });
      expect(refusal, 'not_found');

      await tapKey(tester, 'scenario-publication-hide');
      await waitFor(tester, statusText('visibility: withdrawn'));
    },
    skip: stand == null || !scenarioPublicationTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
