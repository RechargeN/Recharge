import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/shared/primitives/time/utc_instant.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';
import 'package:recharge/app/testing/seeded_event_fixture.dart';

class _Tokens implements BookingFirebaseIdTokenProvider {
  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async =>
      'test-token';
}

class _Check implements BookingAppCheckTokenProvider {
  @override
  Future<String> currentToken({bool forceRefresh = false}) async =>
      'test-check';
}

class _Install implements BookingInstallationIdProvider {
  @override
  Future<String> current() async => 'install-dev';
}

FunctionsIdentitySessionClient _client(
  String expiry,
  InMemoryBookingIdentitySessionStore store, {
  bool emulator = false,
}) => FunctionsIdentitySessionClient(
  endpoint: emulator
      ? BookingBackendEndpoint.devEmulator(
          Uri.parse('http://127.0.0.1:5001/demo-recharge/europe-west1'),
        )
      : BookingBackendEndpoint.devIdentity(
          Uri.parse(
            'https://europe-west1-recharge-dev-n2a01.cloudfunctions.net',
          ),
        ),
  client: MockClient((request) async {
    final data = (jsonDecode(request.body) as Map)['data'] as Map;
    return http.Response(
      jsonEncode({
        'result': {
          'schemaVersion': 1,
          'commandType': data['commandType'],
          'requestId': data['requestId'],
          'kind': 'succeeded',
          'data': {
            'sessionContext': {
              'userId': 'user-server',
              'sessionId': 'session-server',
              'sessionHandle': 'A' * 43,
              'installationId': 'install-dev',
              'expiresAtUtc': expiry,
            },
          },
        },
      }),
      200,
    );
  }),
  tokens: _Tokens(),
  installations: _Install(),
  sessions: store,
  appCheck: _Check(),
  identityProvider: 'google',
);
void main() {
  test(
    'server .000Z example parses exactly; emulator transport preserves establish',
    () async {
      const text = '2026-11-20T10:00:00.000Z';
      expect(UtcInstant.parse(text).value, DateTime.utc(2026, 11, 20, 10));
      final store = InMemoryBookingIdentitySessionStore();
      expect(
        (await _client(
          text,
          store,
          emulator: true,
        ).establish(requestId: 'fixed-example')).sessionId,
        'session-server',
      );
    },
  );
  test(
    'dev transport .000Z establishes and restores an unexpired server Session',
    () async {
      final future = DateTime.now().toUtc().add(const Duration(days: 2));
      final expiry = DateTime.utc(
        future.year,
        future.month,
        future.day,
        10,
      ).toIso8601String();
      expect(expiry, endsWith('.000Z'));
      final store = InMemoryBookingIdentitySessionStore();
      final client = _client(expiry, store);
      expect(
        (await client.establish(requestId: 'establish')).sessionId,
        'session-server',
      );
      final saved = await store.read();
      var restored = false;
      expect(
        (await client.readCurrent(
          requestId: 'restore',
          onAuthContext: (_) async {
            restored = true;
          },
        )).sessionId,
        saved!.sessionId,
      );
      expect(restored, isTrue);
      expect(
        (await client.refresh(
          requestId: 'refresh',
          requireExistingSession: true,
        )).sessionId,
        saved.sessionId,
      );
    },
  );
  for (final invalid in [
    '2099-11-20T10:00:00.000+00:00',
    '2099-11-20T10:00:00.000',
    '2099-02-30T10:00:00.000Z',
  ]) {
    test('intentional strict dev transport refusal: $invalid', () async {
      final store = InMemoryBookingIdentitySessionStore();
      final client = _client(invalid, store);
      await expectLater(
        client.establish(requestId: 'invalid'),
        throwsFormatException,
      );
      expect(await store.read(), isNull);
      await store.saveServerIssued(
        BookingIdentitySessionContext(
          sessionId: 'session-server',
          sessionHandle: 'A' * 43,
          installationId: 'install-dev',
        ),
      );
      await expectLater(
        client.readCurrent(
          requestId: 'invalid-restore',
          onAuthContext: (_) async =>
              fail('invalid response cannot restore authority'),
        ),
        throwsFormatException,
      );
      expect(await store.read(), isNull);
    });
  }
  test(
    'expired dev session stays refused even when syntax is canonical',
    () async {
      final store = InMemoryBookingIdentitySessionStore();
      await expectLater(
        _client(
          '2000-11-20T10:00:00.000Z',
          store,
        ).establish(requestId: 'expired'),
        throwsFormatException,
      );
    },
  );
  test(
    'debug Booking projection accepts route query from UTC toIso8601String',
    () {
      final query = {
        'occurrence': 'occ-1',
        'start': DateTime.utc(2026, 11, 20, 16).toIso8601String(),
        'end': DateTime.utc(2026, 11, 20, 18).toIso8601String(),
      };
      final route = Uri(
        path: '/test/event-booking/evt-1',
        queryParameters: query,
      );
      final projection = publishedTestBookingEventProjection(
        eventId: 'evt-1',
        query: route.queryParameters,
      )!;
      expect(
        projection.occurrences.single.startAtUtc,
        DateTime.utc(2026, 11, 20, 16),
      );
      for (final invalid in [
        '2026-11-20T16:00:00+00:00',
        '2026-11-20T16:00:00',
        '2026-02-30T16:00:00Z',
      ]) {
        expect(
          publishedTestBookingEventProjection(
            eventId: 'evt-1',
            query: {...query, 'start': invalid},
          ),
          isNull,
        );
      }
    },
  );
}
