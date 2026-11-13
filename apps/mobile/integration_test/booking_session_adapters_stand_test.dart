import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/features/booking/data/booking_firebase_auth_emulator.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:uuid/uuid.dart';

// Native adapters on Android Emulator. No plugin mocks, no UI or device claim.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RECHARGE_B1_PLATFORM');
  testWidgets(
    'native Auth and secure Session lifecycle, then localOnly',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final app = await Firebase.initializeApp(
        name: 'recharge-b1-platform',
        options: const FirebaseOptions(
          apiKey: 'demo-recharge-emulator-only',
          appId: '1:1234567890:android:demo-recharge-emulator',
          messagingSenderId: '1234567890',
          projectId: 'demo-recharge',
        ),
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator(
        '127.0.0.1',
        9099,
        automaticHostMapping: false,
      );
      final credential = await auth.signInWithEmailAndPassword(
        email: 'stand-user-viewer@example.invalid',
        password: 'emulator-only-password-123',
      );
      expect(credential.user!.uid, 'stand-user-viewer');
      final binding = BookingBackendBindingController(
        emulatorBase: Uri.parse(
          'http://127.0.0.1:5001/demo-recharge/europe-west1',
        ),
        releaseMode: false,
        initial: BackendBindingMode.testBackend,
      );
      final tokens = bookingFirebaseTokenProviderFor(
        endpoint: binding.endpoint,
        emulator: const BookingAuthEmulatorConfig(host: '127.0.0.1'),
        authFactory: () async => auth,
        releaseMode: false,
      );
      expect(tokens, isA<FirebaseAuthIdTokenProvider>());
      expect(await tokens.currentIdToken(forceRefresh: true), isNotEmpty);
      const storage = FlutterSecureStorage();
      const sessions = SecureBookingIdentitySessionStore(storage);
      await sessions.clear();
      final installation = SecureBookingInstallationIdProvider(storage);
      final installationId = await installation.current();
      final client = _CountingClient();
      addTearDown(client.close);
      final support = await getApplicationSupportDirectory();
      Future<BookingTransportRuntime> build(
        BookingIdentitySessionStore store,
      ) => BookingTransportRuntimeFactory(
        endpoint: binding.endpoint,
        client: client,
        tokens: tokens,
        sessions: store,
        installations: installation,
        supportDirectory: () async => support,
      ).create();
      Future<Map<String, Object?>> fixture(List<String> args) async {
        final response = await http.post(
          Uri.parse('http://127.0.0.1:8765/session-fixture'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(args),
        );
        expect(response.statusCode, 200, reason: response.body);
        return Map<String, Object?>.from(jsonDecode(response.body) as Map);
      }

      Future<void> readBookings(BookingTransportRuntime runtime) async {
        final result = await runtime.port!.invoke('listMyBookingsV1', {
          'schemaVersion': 1,
          'queryType': 'listMyBookings',
          'requestId': const Uuid().v4(),
          'payload': {'pageSize': 20},
        });
        expect(result['kind'], 'succeeded', reason: '$result');
      }

      await fixture(['revoke-active', 'viewer']);
      final first = await build(sessions);
      final issued = await first.identitySessions!.establish(
        requestId: const Uuid().v4(),
      );
      expect(issued.installationId, installationId);
      await readBookings(first);
      const restoredStore = SecureBookingIdentitySessionStore(
        FlutterSecureStorage(),
      );
      expect((await restoredStore.read())!.sessionId, issued.sessionId);
      final restored = await build(restoredStore);
      await readBookings(restored);
      expect((await restoredStore.read())!.sessionId, issued.sessionId);
      await fixture(['revoke-active', 'viewer']);
      await readBookings(restored);
      expect((await restoredStore.read())!.sessionId, isNot(issued.sessionId));
      final expired = BookingIdentitySessionContext.fromJson(
        await fixture(['expired', 'viewer', installationId]),
      );
      await restoredStore.saveServerIssued(expired);
      await readBookings(restored);
      final repaired = (await restoredStore.read())!;
      expect(repaired.sessionId, isNot(expired.sessionId));
      final requests = client.requests;
      binding.activate(BackendBindingMode.localOnly);
      final local = await build(restoredStore);
      expect(local.remoteCommandsEnabled, isFalse);
      expect(local.port, isNull);
      expect(client.requests, requests);
      expect((await restoredStore.read())!.sessionId, repaired.sessionId);
      binding.rollback();
      await readBookings(await build(restoredStore));
      expect(client.requests, greaterThan(requests));
      await auth.signOut();
      expect(await tokens.currentIdToken(), isNull);
      await sessions.clear();
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

class _CountingClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  int requests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
