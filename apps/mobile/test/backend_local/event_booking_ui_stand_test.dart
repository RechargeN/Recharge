import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/booking_test_entry_guard.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/event_booking_panel.dart';
import 'package:recharge/app/presentation/event_details_page.dart';
import 'package:recharge/app/testing/seeded_event_fixture.dart';
import 'package:recharge/core/localization/user_message_catalog.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/application/event_booking_controller.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_event_booking_gateway.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';
import 'package:recharge/features/booking/presentation/event_booking_section.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

import 'support/stand_backend.dart';
import 'support/event_details_harness.dart';

/// B2-local: client -> server Event -> Booking through the real UI, the real
/// controller, the real journal and the real testBackend adapters against the
/// local demo-recharge stand. Only the network between the app and the stand is
/// wrapped, to cut or drop a response; the backend itself is the real one.
///
/// Limits: host run (PC), no physical device, no firebase_auth or secure
/// storage plugin (Session comes from the B1-local Auth Emulator path).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  const user = 'staff';

  late Directory temp;
  late Directory sessionDir;
  late FaultClient client;

  Future<void> bootClient(WidgetTester tester) async {
    await sl.reset();
    final controller = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    sl
      ..registerSingleton<AnalyticsService>(SpyAnalytics())
      ..registerSingleton<TimezoneRepository>(TimezoneRepositoryImpl())
      ..registerSingleton<BookingBackendBindingController>(controller)
      // The real define must be set by the gate (=true), not forced here.
      ..registerSingleton<BookingTestEntryGuard>(
        BookingTestEntryGuard.fromEnvironment(controller),
      )
      ..registerSingleton<BookingSupportDirectoryProvider>(
        () async => Directory('${temp.path}/support').create(recursive: true),
      );
    final sessions = FileSessionStore(File('${sessionDir.path}/session.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: controller.endpoint,
      client: client,
      tokens: AuthEmulatorTokenProvider('stand-user-$user'),
      sessions: sessions,
      installations: const FixedInstallationId('b2-local-installation-staff'),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    // Same registration shape as production (lazy async singleton).
    sl.registerLazySingletonAsync<BookingTransportRuntime>(() async => runtime);
    // Sign-in is the B1-local path; B2 starts from an established Session.
    if (await sessions.read() == null) {
      try {
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
      } on BookingCallableFailure catch (error) {
        fail('establish failed with ${error.code}');
      }
    }
  }

  Future<void> pumpPage(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final authController = await signedInAuthController();
    final favoritesController = favoritesFor();
    final router = GoRouter(
      initialLocation: '/event',
      routes: <RouteBase>[
        GoRoute(
          path: '/event',
          builder: (context, state) =>
              EventDetailsPage(projection: seededBookingEventProjection()),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
    final panel = find.byType(EventBookingPanel).evaluate().length;
    final section = find.byType(EventBookingSection).evaluate().length;
    final unavailable = find
        .byKey(const Key('event-booking-unavailable'))
        .evaluate()
        .length;
    final message = find.byKey(const Key('event-booking-message'));
    final shown = message.evaluate().isEmpty
        ? ''
        : (message.evaluate().first.widget as Text).data;
    final texts = find
        .descendant(
          of: find.byType(EventBookingSection),
          matching: find.byType(Text),
        )
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .join(' | ');
    throw TestFailure(
      'Timed out waiting for $finder (panel=$panel, section=$section, '
      'unavailable=$unavailable, message="$shown", texts=[$texts])',
    );
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byWidgetPredicate(
      (widget) =>
          widget.key == Key(key) &&
          widget is ButtonStyleButton &&
          widget.onPressed != null,
    );
    // A disabled (busy) button must not be tapped: wait until it is enabled.
    await waitFor(tester, finder);
    await tester.tap(finder);
  }

  Future<void> expectActive(int expected, String reason) async {
    final counts = await stand!.bookingCounts(user);
    expect(counts.active, expected, reason: reason);
  }

  Future<void> cancelMine(WidgetTester tester) async {
    await tapKey(tester, 'event-booking-cancel');
    await waitFor(tester, find.byKey(const Key('event-booking-create')));
    await expectActive(0, 'cancel returned the seat');
  }

  // One Session for the whole file: Sessions are rate limited per Account, and
  // the Session itself is the B1-local path, not what B2 exercises.
  setUpAll(() async {
    sessionDir = await Directory.systemTemp.createTemp('b2-local-session-');
  });

  tearDownAll(() async {
    if (await sessionDir.exists()) await sessionDir.delete(recursive: true);
  });

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('b2-local-');
    client = FaultClient();
  });

  tearDown(() async {
    await sl.reset();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  testWidgets(
    'the test entry is on only with the real define, and a booking can be '
    'created, shown and cancelled',
    (WidgetTester tester) async {
      expect(
        bookingTestEntryDefined,
        isTrue,
        reason: 'run with --dart-define=RECHARGE_TEST_BOOKING_ENTRY=true',
      );
      await bootClient(tester);
      await expectActive(0, 'the seeded staff booking is cancelled');
      await pumpPage(tester);

      await tapKey(tester, 'event-booking-create');
      await waitFor(tester, find.byKey(const Key('event-booking-mine')));
      await expectActive(1, 'create');
      expect(
        find.textContaining('Confirmed'),
        findsWidgets,
        reason: 'my booking is shown',
      );

      await cancelMine(tester);
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'a double tap sends one command and creates one booking',
    (WidgetTester tester) async {
      await bootClient(tester);
      final loading = Completer<void>();
      client.holdNextRead = loading;
      await pumpPage(tester);
      await waitFor(tester, find.text('Loading your booking…'));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      loading.complete();
      final create = find.byKey(const Key('event-booking-create'));
      await waitFor(tester, create);

      final held = Completer<void>();
      client.holdNextCreate = held;
      await tester.tap(create);
      await tester.tap(create);
      await waitFor(tester, find.byKey(const Key('event-booking-busy')));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byKey(const Key('event-booking-mine')), findsNothing);
      held.complete();

      await waitFor(tester, find.byKey(const Key('event-booking-mine')));
      await expectActive(1, 'double tap');
      expect(client.createCommands, 1, reason: 'one create command sent');
      await cancelMine(tester);
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'a lost response is an unknown outcome; checking again does not duplicate',
    (WidgetTester tester) async {
      await bootClient(tester);
      await pumpPage(tester);
      client.dropNextCreateResponse = true;

      await tapKey(tester, 'event-booking-create');
      await waitFor(tester, find.byKey(const Key('event-booking-retry')));
      expect(find.textContaining('could not confirm'), findsOneWidget);
      // The server did process the lost request.
      await expectActive(1, 'server processed the dropped request');

      await tapKey(tester, 'event-booking-retry');
      await waitFor(tester, find.byKey(const Key('event-booking-mine')));
      await expectActive(1, 'replay with the same key');
      await cancelMine(tester);
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'the journaled intent survives a restart and recovers without a second '
    'booking',
    (WidgetTester tester) async {
      await bootClient(tester);
      await pumpPage(tester);
      client.dropNextCreateResponse = true;
      await tapKey(tester, 'event-booking-create');
      await waitFor(tester, find.byKey(const Key('event-booking-retry')));

      // Restart: the app is torn down and rebuilt from the same files.
      await tester.pumpWidget(const SizedBox.shrink());
      client = FaultClient();
      await bootClient(tester);
      await pumpPage(tester);

      await waitFor(tester, find.byKey(const Key('event-booking-mine')));
      await expectActive(1, 'recovery after restart');
      expect(client.createCommands, 1, reason: 'recovery replayed the intent');
      await cancelMine(tester);
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'offline is shown honestly and the saved request is sent once afterwards',
    (WidgetTester tester) async {
      await bootClient(tester);
      client.severed = true;
      await pumpPage(tester);

      await waitFor(tester, find.byKey(const Key('event-booking-retry')));
      expect(find.textContaining('No connection'), findsOneWidget);
      client.severed = false;
      await tapKey(tester, 'event-booking-retry');
      await waitFor(tester, find.byKey(const Key('event-booking-create')));

      client.severed = true;
      await tapKey(tester, 'event-booking-create');
      await waitFor(tester, find.byKey(const Key('event-booking-retry')));
      await expectActive(0, 'nothing reached the server while offline');

      client.severed = false;
      await tapKey(tester, 'event-booking-retry');
      await waitFor(tester, find.byKey(const Key('event-booking-mine')));
      await expectActive(1, 'sent once after reconnecting');
      await cancelMine(tester);
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'L4: a real server refusal travels adapter -> controller -> UI and is '
    'shown in Latvian and Russian, never as a code',
    (WidgetTester tester) async {
      for (final String language in <String>['lv', 'ru']) {
        await bootClient(tester);
        await pumpPage(tester, locale: Locale(language));
        final AppLocalizations l10n = lookupAppLocalizations(Locale(language));
        await waitFor(tester, find.byKey(const Key('event-booking-create')));
        await expectActive(0, 'nothing booked yet ($language)');

        // Out of band, the same user books through the real gateway, so the
        // screen still shows "no booking" while the server has one.
        final EventBookingController shown = tester
            .widget<EventBookingSection>(find.byType(EventBookingSection))
            .controller;
        final BookingTransportRuntime runtime = await sl
            .getAsync<BookingTransportRuntime>();
        final EventBookingResult other =
            await BookingTransportEventBookingGateway(
              adapter: runtime.adapter!,
              port: runtime.port!,
              gate: sl<BookingTestEntryGuard>(),
            ).execute(
              EventBookingOperation(
                kind: EventBookingOperationKind.create,
                idempotencyKey: 'l4-${const Uuid().v4()}',
                occurrenceId: shown.occurrenceId,
                inventoryPoolId: shown.inventoryPoolId,
                channel: shown.channel,
                participantUnits: 1,
                eventRevision: shown.eventRevision,
              ),
            );
        expect(other.outcome, EventBookingOutcome.succeeded);
        await expectActive(1, 'booked out of band ($language)');

        // The screen's own create is a new intent; the server refuses it.
        await tapKey(tester, 'event-booking-create');
        final Finder message = find.byKey(const Key('event-booking-message'));
        await waitFor(tester, message);
        final EventBookingMessage? state = shown.state.message;
        final String? code = state?.refusalCode;
        final String text = (tester.widget<Text>(message)).data!;
        expect(state?.notice, EventBookingNotice.refused, reason: text);
        expect(code, isNotNull, reason: text);
        expect(
          UserMessageCatalog.isRegistered(UserMessageFamily.booking, code!),
          isTrue,
          reason: 'the server answered $code',
        );
        expect(text, UserMessageCatalog.booking(l10n, code));
        expect(text.contains(code), isFalse);
        expect(text, isNot(l10n.bookingErrorGeneric));
        await expectActive(1, 'the refusal created nothing ($language)');

        await tapKey(tester, 'event-booking-refresh');
        await waitFor(tester, find.byKey(const Key('event-booking-mine')));
        await cancelMine(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// Real HTTP with two faults: [severed] fails before anything is sent, and
/// [dropNextCreateResponse] lets the request reach the server and then loses
/// the answer.
final class FaultClient extends http.BaseClient {
  FaultClient() : _inner = http.Client();

  final http.Client _inner;
  bool severed = false;
  bool dropNextCreateResponse = false;
  int createCommands = 0;
  Completer<void>? holdNextCreate;
  Completer<void>? holdNextRead;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isCreate = request.url.path.endsWith('/createInternalBookingV1');
    if (severed) throw const SocketException('simulated: no connection');
    if (!isCreate && holdNextRead != null) {
      final held = holdNextRead!;
      holdNextRead = null;
      await held.future;
    }
    if (isCreate) {
      createCommands += 1;
      final held = holdNextCreate;
      holdNextCreate = null;
      if (held != null) await held.future;
    }
    // F2: every request on a fresh connection. The stand command before a
    // cancel can idle ~5 s, Node's keep-alive limit; a reused socket closed by
    // the server would turn a real cancel into an unknown outcome. The lost
    // response and offline checks below are unchanged.
    request.persistentConnection = false;
    final response = await _inner.send(request);
    if (isCreate && dropNextCreateResponse) {
      dropNextCreateResponse = false;
      await response.stream.drain<void>();
      throw const SocketException('simulated: response lost');
    }
    return response;
  }
}
