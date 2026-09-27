import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/core/network/backend_clients.dart';
import 'package:recharge/core/network/backend_transport.dart';
import 'package:recharge/core/sync/backend_import.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_firebase_auth_emulator.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';
import 'package:recharge/features/booking/data/booking_persistence_store.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';

void main() {
  final endpoint = BookingBackendEndpoint.devEmulator(
    Uri.parse('http://127.0.0.1:5001/demo-recharge/europe-west1'),
  );
  final session = BookingIdentitySessionContext(
    sessionId: 'session_001',
    sessionHandle: 'A' * 43,
    installationId: 'installation-001',
  );

  test('Functions port injects only server-issued Identity Session', () async {
    late Map<String, Object?> sent;
    late Map<String, String> headers;
    final client = MockClient((request) async {
      headers = request.headers;
      final envelope = jsonDecode(request.body) as Map<String, dynamic>;
      sent = Map<String, Object?>.from(envelope['data'] as Map);
      return http.Response(
        jsonEncode(<String, Object?>{'result': _commandSuccess()}),
        200,
      );
    });
    final sessions = InMemoryBookingIdentitySessionStore();
    await sessions.saveServerIssued(session);
    final port = FunctionsBookingCallablePort(
      endpoint: endpoint,
      client: client,
      tokens: const _TokenProvider('firebase-id-token'),
      sessions: sessions,
    );

    final result = await port.invoke(
      'createInternalBookingV1',
      <String, Object?>{
        'schemaVersion': 1,
        'commandType': 'createBooking',
        'requestId': 'request_001',
        'idempotencyKey': 'idempotency_001',
        'sessionContext': <String, Object?>{
          'sessionId': 'client-substitution',
          'sessionHandle': 'B' * 43,
          'installationId': 'client-installation',
        },
        'payload': <String, Object?>{
          'occurrenceId': 'occurrence_001',
          'participantUnits': 1,
        },
      },
    );

    expect(result['kind'], 'succeeded');
    expect(
      headers[HttpHeaders.authorizationHeader],
      'Bearer firebase-id-token',
    );
    expect(sent['sessionContext'], session.toJson());
    expect(jsonEncode(sent), isNot(contains('capabilities')));
  });

  test('missing real token or server Session fails before dispatch', () async {
    var requests = 0;
    final port = FunctionsBookingCallablePort(
      endpoint: endpoint,
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      tokens: const DisabledBookingFirebaseIdTokenProvider(),
      sessions: InMemoryBookingIdentitySessionStore(),
    );

    await expectLater(
      port.invoke('createInternalBookingV1', const <String, Object?>{}),
      throwsA(
        isA<BookingCallableFailure>()
            .having((value) => value.dispatched, 'dispatched', isFalse)
            .having((value) => value.code, 'code', 'unauthenticated'),
      ),
    );
    expect(requests, 0);
  });

  test('transport performs one forced Firebase token refresh after unauthenticated', () async {
    var requests = 0;
    final tokens = _TrackingTokenProvider();
    final sessions = InMemoryBookingIdentitySessionStore();
    await sessions.saveServerIssued(session);
    final port = FunctionsBookingCallablePort(
      endpoint: endpoint,
      client: MockClient((_) async {
        requests += 1;
        if (requests == 1) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{'status': 'UNAUTHENTICATED'},
            }),
            401,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{'result': _commandSuccess()}),
          200,
        );
      }),
      tokens: tokens,
      sessions: sessions,
    );
    expect(
      (await port.invoke('createInternalBookingV1', <String, Object?>{
        'schemaVersion': 1,
        'commandType': 'createBooking',
        'requestId': 'request-token-refresh',
        'idempotencyKey': 'idempotency-token-refresh',
        'payload': <String, Object?>{
          'occurrenceId': 'occurrence_001',
          'participantUnits': 1,
        },
      }))['kind'],
      'succeeded',
    );
    expect(tokens.forceRefreshCalls, 1);
    expect(requests, 2);
  });

  test('release selector never initializes Firebase and always returns disabled provider', () async {
    var initialized = false;
    final provider = bookingFirebaseTokenProviderFor(
      endpoint: endpoint,
      emulator: const BookingAuthEmulatorConfig(host: '127.0.0.1'),
      releaseMode: true,
      authFactory: () async {
        initialized = true;
        throw StateError('Firebase must not initialize in release');
      },
    );
    expect(provider, isA<DisabledBookingFirebaseIdTokenProvider>());
    expect(await provider.currentIdToken(), isNull);
    expect(initialized, isFalse);
  });

  test(
    'network timeout after send is an ambiguous dispatched failure',
    () async {
      final sessions = InMemoryBookingIdentitySessionStore();
      await sessions.saveServerIssued(session);
      final port = FunctionsBookingCallablePort(
        endpoint: endpoint,
        client: MockClient((_) => Completer<http.Response>().future),
        tokens: const _TokenProvider('firebase-id-token'),
        sessions: sessions,
        timeout: const Duration(milliseconds: 5),
      );

      await expectLater(
        port.invoke('getMyBookingV1', const <String, Object?>{
          'schemaVersion': 1,
          'queryType': 'getMyBooking',
          'requestId': 'request_002',
          'payload': <String, Object?>{'bookingId': 'booking_001'},
        }),
        throwsA(
          isA<BookingCallableFailure>()
              .having((value) => value.dispatched, 'dispatched', isTrue)
              .having((value) => value.code, 'code', 'deadline-exceeded'),
        ),
      );
    },
  );

  test(
    'Identity callable persists only opaque server Session context',
    () async {
      final sessions = InMemoryBookingIdentitySessionStore();
      final client = FunctionsIdentitySessionClient(
        endpoint: endpoint,
        client: MockClient((request) async {
          expect(
            request.headers[HttpHeaders.authorizationHeader],
            'Bearer token',
          );
          return http.Response(
            jsonEncode(<String, Object?>{
              'result': <String, Object?>{
                'schemaVersion': 1,
                'commandType': 'establishIdentitySession',
                'requestId': 'request_identity',
                'serverTime': '2026-09-26T12:00:00.000Z',
                'kind': 'succeeded',
                'data': <String, Object?>{
                  'sessionContext': <String, Object?>{
                    ...session.toJson(),
                    'userId': 'server-user-never-persisted',
                    'expiresAtUtc': '2026-09-26T12:15:00.000Z',
                    'capabilities': <String>['never-trusted-by-mobile'],
                  },
                },
              },
            }),
            200,
          );
        }),
        tokens: const _TokenProvider('token'),
        installations: const _InstallationProvider('installation-001'),
        sessions: sessions,
      );

      final issued = await client.establish(requestId: 'request_identity');
      expect(issued.toJson(), session.toJson());
      expect((await sessions.read())?.toJson(), session.toJson());
    },
  );

  test(
    'journal survives restart, compacts and serializes concurrent writers',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'booking_journal_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/booking.json');
      var now = DateTime.utc(2026, 9, 26, 12);
      final first = FileBookingPersistenceStore(
        file,
        clock: () => now,
        maximumReceipts: 8,
        maximumImports: 2,
      );
      final second = FileBookingPersistenceStore(
        file,
        clock: () => now,
        maximumReceipts: 8,
        maximumImports: 2,
      );

      await Future.wait(
        List<Future<void>>.generate(12, (index) async {
          final store = index.isEven ? first : second;
          store.receiptStore.write(
            'idem_$index',
            BackendReceipt(
              operation: 'createInternalBookingV1',
              semanticHash: 'hash_$index',
              response: BackendResponse(
                statusCode: 200,
                body: _commandSuccess(),
              ),
            ),
          );
        }),
      );
      final restarted = FileBookingPersistenceStore(file, clock: () => now);
      final persisted =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect((persisted['receipts'] as Map).length, 8);
      for (var index = 0; index < 3; index++) {
        now = now.add(const Duration(minutes: 1));
        first.importStore.write(
          ImportReceipt(
            localId: 'local_$index',
            serverId: 'server_$index',
            semanticHash: 'import_hash_$index',
            serverRevision: index,
          ),
        );
      }
      expect(restarted.importStore.read('local_0'), isNull);
      expect(restarted.importStore.read('local_2'), isNotNull);

      now = now.add(const Duration(days: 8));
      restarted.compact();
      expect(restarted.receiptStore.read('idem_0'), isNull);
    },
  );

  test(
    'journal fails closed when the configured file limit is exceeded',
    () async {
      final directory = await Directory.systemTemp.createTemp('booking_limit_');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/booking.json')
        ..writeAsStringSync('x' * 129);
      final store = FileBookingPersistenceStore(file, maximumFileBytes: 128);
      expect(
        () => store.operationStore.read('idem'),
        throwsA(
          isA<BookingPersistenceException>().having(
            (value) => value.code,
            'code',
            'booking_journal_too_large',
          ),
        ),
      );
    },
  );

  test(
    'runtime factory defaults to rollback and keeps production disabled',
    () async {
      Future<Directory> unexpectedDirectory() =>
          throw StateError('disabled binding must not touch persistence');
      BookingTransportRuntimeFactory factory(BookingBackendEndpoint binding) =>
          BookingTransportRuntimeFactory(
            endpoint: binding,
            client: MockClient((_) async => http.Response('{}', 500)),
            tokens: const DisabledBookingFirebaseIdTokenProvider(),
            sessions: InMemoryBookingIdentitySessionStore(),
            installations: const _InstallationProvider('installation-001'),
            supportDirectory: unexpectedDirectory,
          );

      expect(
        (await factory(
          const BookingBackendEndpoint.localMock(),
        ).create()).binding,
        BookingBackendBinding.localMock,
      );
      final production = await factory(
        const BookingBackendEndpoint.productionDisabled(),
      ).create();
      expect(production.binding, BookingBackendBinding.productionDisabled);
      expect(production.remoteCommandsEnabled, isFalse);
    },
  );
}

Map<String, Object?> _commandSuccess() => <String, Object?>{
  'schemaVersion': 1,
  'kind': 'succeeded',
  'requestId': 'request_001',
  'correlationId': 'correlation_001',
  'serverTime': '2026-09-26T12:00:00.000Z',
};

final class _TokenProvider implements BookingFirebaseIdTokenProvider {
  const _TokenProvider(this.token);
  final String token;

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async => token;
}

final class _InstallationProvider implements BookingInstallationIdProvider {
  const _InstallationProvider(this.value);
  final String value;

  @override
  Future<String> current() async => value;
}

final class _TrackingTokenProvider implements BookingFirebaseIdTokenProvider {
  int forceRefreshCalls = 0;

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async {
    if (forceRefresh) forceRefreshCalls += 1;
    return forceRefresh ? 'refreshed-token' : 'initial-token';
  }
}
