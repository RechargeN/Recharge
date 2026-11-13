import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/booking_test_entry_guard.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/event_details_page.dart';
import 'package:recharge/app/testing/seeded_event_fixture.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_firebase_auth_emulator.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

import '../test/backend_local/support/event_details_harness.dart';
import '../test/backend_local/support/stand_backend.dart';
import '../test/backend_local/support/stand_environment.dart';

/// B1-device: the real installed app on the phone across real process ends.
///
/// One test, three launches by `stand-b1-device-gate.mjs`, the same app data:
/// 1. native firebase_auth sign-in, a server-issued Session in secure storage,
///    an Event Booking whose answer is lost (unknown outcome, journaled), then
///    the app goes to the background and returns; then the gate sends it to
///    the background again and ends the process the way Android does (`am
///    kill`);
/// 2. a cold start restores the Firebase user, the same Session and the
///    journal, and recovers the one Booking without a second; it is cancelled;
///    then the gate closes the app as a user would (`am force-stop`);
/// 3. a cold start restores the Session again; owner-path revoke and expiry
///    are repaired; `localOnly` makes no call and is rolled back.
///
/// Not mocked: firebase_auth, flutter_secure_storage, path_provider, HTTP,
/// lifecycle and process death. Stand fixtures and Booking counts run on the
/// PC through the gate's loopback bridge.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final StandBackend? stand = StandBackend.fromEnvironment();
  final int phase =
      int.tryParse(standEnvironment['RECHARGE_B1_PHASE'] ?? '') ?? 0;
  const String user = 'staff';
  const String uid = 'stand-user-$user';

  testWidgets(
    'B1-device lifecycle phase $phase',
    (WidgetTester tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(<int>[1, 2, 3], contains(phase));
      expect(bookingTestEntryDefined, isTrue);
      final FirebaseApp app = await Firebase.initializeApp(
        name: 'recharge-b1-device',
        options: const FirebaseOptions(
          apiKey: 'demo-recharge-emulator-only',
          appId: '1:1234567890:android:demo-recharge-emulator',
          messagingSenderId: '1234567890',
          projectId: 'demo-recharge',
        ),
      );
      final FirebaseAuth auth = FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator(
        '127.0.0.1',
        9099,
        automaticHostMapping: false,
      );
      const FlutterSecureStorage storage = FlutterSecureStorage();
      const SecureBookingIdentitySessionStore sessions =
          SecureBookingIdentitySessionStore(storage);
      final SecureBookingInstallationIdProvider installation =
          SecureBookingInstallationIdProvider(storage);
      final Directory support = await Directory(
        '${(await getApplicationSupportDirectory()).path}/b1-device',
      ).create(recursive: true);

      if (phase == 1) {
        await auth.signOut();
        await sessions.clear();
        final UserCredential credential = await auth.signInWithEmailAndPassword(
          email: '$uid@example.invalid',
          password: StandBackend.emulatorPassword,
        );
        expect(credential.user!.uid, uid);
      } else {
        // A cold start: the native plugin restores the user without a sign-in.
        expect(auth.currentUser?.uid, uid, reason: 'Firebase user restored');
      }

      final BookingBackendBindingController binding =
          BookingBackendBindingController(
            emulatorBase: StandBackend.functionsBase,
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          );
      final BookingFirebaseIdTokenProvider tokens =
          bookingFirebaseTokenProviderFor(
            endpoint: binding.endpoint,
            emulator: const BookingAuthEmulatorConfig(host: '127.0.0.1'),
            authFactory: () async => auth,
            releaseMode: false,
          );
      expect(tokens, isA<FirebaseAuthIdTokenProvider>());
      final _DroppingClient client = _DroppingClient();
      addTearDown(client.close);
      Future<BookingTransportRuntime> runtime() =>
          BookingTransportRuntimeFactory(
            endpoint: binding.endpoint,
            client: client,
            tokens: tokens,
            sessions: sessions,
            installations: installation,
            supportDirectory: () async => support,
          ).create();

      Future<void> pumpEvent(BookingTransportRuntime built) async {
        await sl.reset();
        sl
          ..registerSingleton<AnalyticsService>(SpyAnalytics())
          ..registerSingleton<TimezoneRepository>(TimezoneRepositoryImpl())
          ..registerSingleton<BookingBackendBindingController>(binding)
          ..registerSingleton<BookingTestEntryGuard>(
            BookingTestEntryGuard.fromEnvironment(binding),
          )
          ..registerSingleton<BookingSupportDirectoryProvider>(
            () async => support,
          )
          ..registerLazySingletonAsync<BookingTransportRuntime>(
            () async => built,
          );
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
        final auth = await signedInAuthController();
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              authControllerProvider.overrideWith((ref) => auth),
              favoritesControllerProvider.overrideWith((ref) => favoritesFor()),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
            ),
          ),
        );
      }

      Future<void> waitFor(Finder finder) async {
        final DateTime deadline = DateTime.now().add(
          const Duration(minutes: 2),
        );
        while (finder.evaluate().isEmpty) {
          if (DateTime.now().isAfter(deadline)) fail('timed out on $finder');
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      Future<void> tapKey(String key) async {
        final Finder enabled = find.byWidgetPredicate(
          (widget) =>
              widget.key == Key(key) &&
              widget is ButtonStyleButton &&
              widget.onPressed != null,
        );
        await waitFor(enabled);
        await tester.tap(enabled);
      }

      Future<void> expectBookings({
        required int total,
        required int active,
      }) async {
        final ({int total, int active}) counts = await stand!.bookingCounts(
          user,
        );
        expect(counts.total, total, reason: 'no duplicate Booking');
        expect(counts.active, active);
      }

      Future<String> sessionId() async => (await sessions.read())!.sessionId;

      Future<void> readBookings(BookingTransportRuntime built) async {
        final Map<String, Object?> result = await built.port!.invoke(
          'listMyBookingsV1',
          <String, Object?>{
            'schemaVersion': 1,
            'queryType': 'listMyBookings',
            'requestId': const Uuid().v4(),
            'payload': <String, Object?>{'pageSize': 20},
          },
        );
        expect(result['kind'], 'succeeded', reason: '$result');
      }

      final ({int total, int active}) base = await stand!.bookingCounts(user);

      if (phase == 1) {
        final BookingTransportRuntime first = await runtime();
        await first.identitySessions!.establish(requestId: const Uuid().v4());
        await readBookings(first);
        final String issued = await sessionId();
        await pumpEvent(first);
        client.dropNextCreateResponse = true;
        await tapKey('event-booking-create');
        await waitFor(find.byKey(const Key('event-booking-retry')));
        await expectBookings(total: base.total + 1, active: 1);

        // Background and back: the gate presses Home, then reopens the app.
        final _Lifecycle lifecycle = _Lifecycle();
        WidgetsBinding.instance.addObserver(lifecycle);
        await _arrive('background', <String, Object?>{'sessionId': issued});
        await _gate('foreground');
        // Returning passes through inactive; wait for the app to be resumed.
        final DateTime resumeBy = DateTime.now().add(
          const Duration(minutes: 1),
        );
        while (lifecycle.states.isEmpty ||
            lifecycle.states.last != AppLifecycleState.resumed) {
          if (DateTime.now().isAfter(resumeBy)) {
            fail('not resumed: ${lifecycle.states}');
          }
          await tester.pump(const Duration(milliseconds: 200));
        }
        await waitFor(find.byKey(const Key('event-booking-retry')));
        WidgetsBinding.instance.removeObserver(lifecycle);
        expect(lifecycle.states, contains(AppLifecycleState.paused));
        expect(lifecycle.states.last, AppLifecycleState.resumed);
        await readBookings(first);
        expect(await sessionId(), issued, reason: 'same Session after resume');

        // The gate now ends this process from the background (`am kill`).
        await _arrive('kill', <String, Object?>{
          'sessionId': issued,
          'states': lifecycle.states.map((state) => state.name).toList(),
          'baseTotal': base.total,
        });
        await _gate('never', timeout: const Duration(minutes: 10));
        fail('the gate did not end the process');
      }

      final Map<String, Object?> killed = await _point('device', 'kill');
      final String issued = killed['sessionId']! as String;
      final int baseTotal = killed['baseTotal']! as int;
      expect(await sessionId(), issued, reason: 'Session survived the restart');

      if (phase == 2) {
        // The journaled create is recovered once; nothing is booked twice.
        await pumpEvent(await runtime());
        await waitFor(find.byKey(const Key('event-booking-mine')));
        await expectBookings(total: baseTotal + 1, active: 1);
        await tapKey('event-booking-cancel');
        await waitFor(find.byKey(const Key('event-booking-create')));
        await expectBookings(total: baseTotal + 1, active: 0);
        await _arrive('force-stop');
        await _gate('never', timeout: const Duration(minutes: 10));
        fail('the gate did not close the app');
      }

      // Phase 3: after the user closed the app.
      final BookingTransportRuntime restored = await runtime();
      await readBookings(restored);
      expect(await sessionId(), issued);
      await stand.sessionFixture(<String>['revoke-active', user]);
      await readBookings(restored);
      final String replaced = await sessionId();
      expect(replaced, isNot(issued), reason: 'revoked Session repaired');
      final BookingIdentitySessionContext expired =
          BookingIdentitySessionContext.fromJson(
            await stand.sessionFixture(<String>[
              'expired',
              user,
              await installation.current(),
            ]),
          );
      await sessions.saveServerIssued(expired);
      await readBookings(restored);
      expect(await sessionId(), isNot(expired.sessionId), reason: 'expired');
      final int requests = client.requests;
      binding.activate(BackendBindingMode.localOnly);
      final BookingTransportRuntime local = await runtime();
      expect(local.remoteCommandsEnabled, isFalse);
      expect(local.port, isNull);
      expect(client.requests, requests, reason: 'localOnly makes no call');
      binding.rollback();
      await readBookings(await runtime());
      expect(client.requests, greaterThan(requests));
      await expectBookings(total: baseTotal + 1, active: 0);
      await auth.signOut();
      expect(await tokens.currentIdToken(), isNull);
      await sessions.clear();
      await _arrive('done');
    },
    skip: stand == null || phase == 0,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

final class _Lifecycle with WidgetsBindingObserver {
  final List<AppLifecycleState> states = <AppLifecycleState>[];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => states.add(state);
}

Uri _rendezvous(String who, String name) => standBridgeBase.replace(
  path: '/rendezvous',
  queryParameters: <String, String>{'who': who, 'name': name},
);

/// Tells the gate this launch reached [name].
Future<void> _arrive(
  String name, [
  Map<String, Object?> payload = const <String, Object?>{},
]) async {
  final http.Response response = await http.put(
    _rendezvous('device', name),
    headers: const <String, String>{'content-type': 'application/json'},
    body: jsonEncode(payload),
  );
  expect(response.statusCode, 204, reason: 'bridge refused $name');
}

/// What [who] left at [name], once it is there.
Future<Map<String, Object?>> _point(
  String who,
  String name, {
  Duration timeout = const Duration(minutes: 3),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (true) {
    final http.Response response = await http.get(_rendezvous(who, name));
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as Map).cast<String, Object?>();
    }
    if (response.statusCode != 404) fail('bridge refused $who.$name');
    if (DateTime.now().isAfter(deadline)) fail('$who never reached $name');
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

Future<void> _gate(String name, {Duration? timeout}) =>
    _point('gate', name, timeout: timeout ?? const Duration(minutes: 3));

/// Real HTTP; [dropNextCreateResponse] lets one create reach the server and
/// loses its answer, as a dropped connection would.
final class _DroppingClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  bool dropNextCreateResponse = false;
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests += 1;
    request.persistentConnection = false;
    final http.StreamedResponse response = await _inner.send(request);
    if (dropNextCreateResponse &&
        request.url.path.endsWith('/createInternalBookingV1')) {
      dropNextCreateResponse = false;
      await response.stream.drain<void>();
      throw const SocketException('simulated: response lost');
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
