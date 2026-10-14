import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/place_publication_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/place_publication_panel.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_place_draft.dart';
import 'support/event_details_harness.dart';
import 'support/stand_backend.dart';

/// D3.1 through the UI: the signed-in user's Create Place draft is published
/// from the default-off test page with the real controller, Create repository,
/// Content/Media adapters and the local demo-recharge stand; staff review is
/// the C2 staff script. The define `RECHARGE_TEST_PLACE_PUBLICATION=true` must
/// come from the gate: the guard is the production one.
///
/// Limits: PC host run (no physical device), Session from the B1-local Auth
/// Emulator path, Media with the existing fake scanner/processor.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late List<File> gallery;

  Future<void> boot() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await stand!.placeSeed();
    final String pageId = (await stand.placeManifest())['pageId']! as String;
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
      userPlaceDraft(
        pageId: pageId,
        coverPath: cover.path,
        galleryPaths: gallery.map((file) => file.path).toList(),
        localId: 'loc_d31_ui_${const Uuid().v4()}',
        title: 'Kronvalda pond (UI path)',
      ),
    );
    final sessions = FileSessionStore(File('${temp.path}/session.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: const FixedInstallationId('d31-ui-installation-creator'),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    sl
      ..registerSingleton<BookingBackendBindingController>(binding)
      ..registerSingleton<PlacePublicationTestEntryGuard>(
        PlacePublicationTestEntryGuard.fromEnvironment(binding),
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
    final status = find.byKey(const Key('place-publication-status'));
    final message = find.byKey(const Key('place-publication-message'));
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
        widget.key == const Key('place-publication-status') &&
        (widget.data ?? '').contains(fragment),
  );

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('d31-ui-');
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
    'the user publishes their Create Place draft from the test page',
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
        initialLocation: '/test/place-publication',
        routes: <RouteBase>[
          GoRoute(
            path: '/test/place-publication',
            redirect: (context, state) => placePublicationTestEntryRedirect(
              sl<PlacePublicationTestEntryGuard>(),
              fallback: '/blocked',
            ),
            builder: (context, state) => const PlacePublicationPage(),
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
      await waitFor(tester, find.text('Kronvalda pond (UI path)'));

      await tapKey(tester, 'place-publication-save');
      await waitFor(tester, statusText('review: draft'));
      await tapKey(tester, 'place-publication-media-upload');
      await waitFor(tester, find.text('Media uploaded: 3'));
      expect(find.byKey(const Key('place-publication-message')), findsNothing);
      await tapKey(tester, 'place-publication-submit');
      await waitFor(tester, statusText('review: under_review'));

      // Staff review through the C2 staff script, for exactly this object.
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            (widget.key as ValueKey<String>?)?.value.startsWith(
                  'place-publication-object-',
                ) ==
                true,
      );
      final contentId = (tester.widget<ListTile>(tile).key! as ValueKey<String>)
          .value
          .substring('place-publication-object-'.length);
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
          'd3.1 UI: approved',
        ]),
      );
      expect(approved!.exitCode, 0, reason: '${approved.json}');

      await tapKey(tester, 'place-publication-refresh');
      await waitFor(tester, statusText('approved_for_publication'));
      await tapKey(tester, 'place-publication-publish');
      await waitFor(tester, statusText('visibility: visible'));
      expect(
        find.byKey(const Key('place-publication-revision')),
        findsOneWidget,
      );

      await tapKey(tester, 'place-publication-hide');
      await waitFor(tester, statusText('visibility: withdrawn'));
      expect(
        find.descendant(of: tile, matching: find.textContaining('withdrawn')),
        findsOneWidget,
      );
    },
    skip: stand == null || !placePublicationTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
