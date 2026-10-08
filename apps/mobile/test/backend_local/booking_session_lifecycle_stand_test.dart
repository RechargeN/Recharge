import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:uuid/uuid.dart';

import 'support/stand_backend.dart';

/// B1-local: mobile Booking adapters and the Identity Session lifecycle against
/// the real local demo-recharge stand. The Auth token is real (Auth Emulator),
/// the Session and Bookings are real (Functions + Firestore), and every
/// revoke/expiry is produced by the backend owner service, not by a mock.
///
/// Sessions are rate limited per Account (5 issues / 15 min, abuse_policy.ts),
/// so the scenarios are spread over the seed users and each stays inside that
/// budget; every gate run starts from a freshly reset and seeded stand.
///
/// Limits: the firebase_auth plugin and the secure-storage plugin cannot run in
/// a host test; they are covered on Android in B1-device.
void main() {
  final stand = StandBackend.fromEnvironment();
  final skip = stand == null ? StandBackend.skipReason : false;
  const uuid = Uuid();

  late Directory temp;
  late File sessionFile;

  String uidOf(String label) => 'stand-user-$label';
  String installationOf(String label) => 'b1-local-installation-$label';

  Map<String, Object?> listBookings() => <String, Object?>{
    'schemaVersion': 1,
    'queryType': 'listMyBookings',
    'requestId': uuid.v4(),
    'payload': <String, Object?>{'pageSize': 20},
  };

  ({
    FunctionsBookingCallablePort port,
    FunctionsIdentitySessionClient identity,
    FileSessionStore sessions,
    AuthEmulatorTokenProvider tokens,
  })
  build(String label) {
    final sessions = FileSessionStore(sessionFile);
    final tokens = AuthEmulatorTokenProvider(uidOf(label));
    final client = http.Client();
    final identity = FunctionsIdentitySessionClient(
      endpoint: stand!.endpoint,
      client: client,
      tokens: tokens,
      installations: FixedInstallationId(installationOf(label)),
      sessions: sessions,
    );
    return (
      port: FunctionsBookingCallablePort(
        endpoint: stand.endpoint,
        client: client,
        tokens: tokens,
        sessions: sessions,
        identitySessions: identity,
      ),
      identity: identity,
      sessions: sessions,
      tokens: tokens,
    );
  }

  /// Turns a transport failure into a readable test failure with its code.
  Future<T> step<T>(String name, Future<T> Function() action) async {
    try {
      return await action();
    } on BookingCallableFailure catch (error) {
      fail('$name failed with ${error.code} (dispatched: ${error.dispatched})');
    }
  }

  Future<List<Object?>> items(FunctionsBookingCallablePort port) async {
    final result = await step(
      'listMyBookings',
      () => port.invoke('listMyBookingsV1', listBookings()),
    );
    expect(result['kind'], 'succeeded', reason: '$result');
    final page = Map<String, Object?>.from(result['page'] as Map);
    return List<Object?>.from(page['items'] as List);
  }

  Future<void> noLiveSession(String label) async {
    await stand!.sessionFixture(<String>['revoke-active', label]);
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('b1-local-');
    sessionFile = File('${temp.path}/session.json');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'sign-in establishes a server-issued Session that survives a restart',
    () async {
      await noLiveSession('viewer');
      final first = build('viewer');

      final issued = await step(
        'establish',
        () => first.identity.establish(requestId: uuid.v4()),
      );

      expect(issued.installationId, installationOf('viewer'));
      expect(first.tokens.signIns, 1);
      // The server resolved the seed Account: its seeded Booking is visible.
      expect(await items(first.port), hasLength(1));

      // A restart is new objects reading the persisted Session: no new
      // establish command, the same Session keeps working.
      final second = build('viewer');
      expect((await second.sessions.read())!.sessionId, issued.sessionId);
      expect(await items(second.port), hasLength(1));
      expect((await second.sessions.read())!.sessionId, issued.sessionId);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a revoked Session is repaired through the owner path, not reused',
    () async {
      await noLiveSession('creator');
      final client = build('creator');
      final issued = await step(
        'establish',
        () => client.identity.establish(requestId: uuid.v4()),
      );

      final revoked = await stand!.sessionFixture(<String>[
        'revoke-active',
        'creator',
      ]);
      expect(revoked['revoked'], greaterThanOrEqualTo(1));

      expect(await items(client.port), hasLength(1));
      final repaired = (await client.sessions.read())!;
      expect(repaired.sessionId, isNot(issued.sessionId));
      expect(repaired.sessionHandle, isNot(issued.sessionHandle));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'an expired Session is replaced and the command is retried once',
    () async {
      final client = build('staff');
      final fixture = await stand!.sessionFixture(<String>[
        'expired',
        'staff',
        installationOf('staff'),
      ]);
      final expired = BookingIdentitySessionContext.fromJson(fixture);
      await client.sessions.saveServerIssued(expired);

      await items(client.port);
      final replaced = (await client.sessions.read())!;
      expect(replaced.sessionId, isNot(expired.sessionId));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'testBackend returns to localOnly without a call or data loss, and back',
    () async {
      await noLiveSession('staff');
      final controller = BookingBackendBindingController(
        emulatorBase: StandBackend.functionsBase,
        releaseMode: false,
        initial: BackendBindingMode.testBackend,
      );
      final counting = CountingClient();
      final sessions = FileSessionStore(sessionFile);
      final tokens = AuthEmulatorTokenProvider(uidOf('staff'));
      final support = Directory('${temp.path}/support');

      Future<BookingTransportRuntime> runtime() {
        return BookingTransportRuntimeFactory(
          endpoint: controller.endpoint,
          client: counting,
          tokens: tokens,
          sessions: sessions,
          installations: FixedInstallationId(installationOf('staff')),
          supportDirectory: () async => support.create(recursive: true),
        ).create();
      }

      final live = await runtime();
      expect(live.remoteCommandsEnabled, isTrue);
      final issued = await step(
        'establish',
        () => live.identitySessions!.establish(requestId: uuid.v4()),
      );
      final before = counting.requests;
      final localData = await _listing(temp);

      controller.activate(BackendBindingMode.localOnly);
      final local = await runtime();
      expect(local.remoteCommandsEnabled, isFalse);
      expect(local.adapter, isNull);
      expect(counting.requests, before, reason: 'localOnly made a request');
      expect(await _listing(temp), localData, reason: 'local data changed');

      controller.rollback();
      final again = await runtime();
      expect(again.remoteCommandsEnabled, isTrue);
      final refreshed = await step(
        'refresh',
        () => again.identitySessions!.refresh(requestId: uuid.v4()),
      );
      expect(refreshed.installationId, issued.installationId);
      expect(counting.requests, greaterThan(before));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<Map<String, int>> _listing(Directory root) async => <String, int>{
  await for (final entity in root.list(recursive: true))
    if (entity is File) entity.path: await entity.length(),
};
