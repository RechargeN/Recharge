import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';

// Gap plan round 2, item 2.6: the App Check token went only with the Identity
// Session calls. Content, Discover, Library, Route, Scenario, Quick Plan,
// Notifications and Media go through FunctionsBookingCallablePort and reached
// the server without it (observe log: present=false). The port now attaches
// the token in observe mode: it never blocks or fails a call.
void main() {
  final endpoint = BookingBackendEndpoint.devIdentity(
    Uri.parse('https://europe-west1-recharge-staging-y9y2y.cloudfunctions.net'),
  );
  final session = BookingIdentitySessionContext(
    sessionId: 'session_001',
    sessionHandle: 'A' * 43,
    installationId: 'installation-001',
  );

  Future<({List<http.Request> requests, Map<String, Object?> result})> call(
    BookingAppCheckTokenProvider? appCheck, {
    String callable = 'contentQueryV1',
    List<String> errorCodes = const [],
  }) async {
    final requests = <http.Request>[];
    var responses = 0;
    final client = MockClient((request) async {
      requests.add(request);
      final code = responses < errorCodes.length ? errorCodes[responses] : null;
      responses += 1;
      if (code == 'unauthenticated') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{'status': 'UNAUTHENTICATED'},
          }),
          401,
        );
      }
      return http.Response(
        jsonEncode(<String, Object?>{
          'result': <String, Object?>{'schemaVersion': 1, 'kind': 'succeeded'},
        }),
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
      appCheck: appCheck,
    );
    final result = await port.invoke(callable, <String, Object?>{
      'schemaVersion': 1,
      'requestId': 'request_001',
    });
    return (requests: requests, result: result);
  }

  test('every product call carries the App Check token', () async {
    for (final callable in const [
      'contentQueryV1',
      'discoverQueryV1',
      'libraryCommandV1',
      'routeQueryV1',
      'notificationsQueryV1',
      'mediaCommandV1',
    ]) {
      final sent = await call(
        const _AppCheck('app-check-token'),
        callable: callable,
      );
      expect(sent.requests, hasLength(1), reason: callable);
      expect(
        sent.requests.single.headers['X-Firebase-AppCheck'],
        'app-check-token',
        reason: callable,
      );
      expect(sent.result['kind'], 'succeeded', reason: callable);
    }
  });

  test('an empty token is not sent and does not block the call', () async {
    final sent = await call(const _AppCheck(''));
    expect(sent.requests, hasLength(1));
    expect(
      sent.requests.single.headers.containsKey('X-Firebase-AppCheck'),
      isFalse,
    );
    expect(sent.result['kind'], 'succeeded');
  });

  test(
    'a failing token provider does not block the call (observe mode)',
    () async {
      final sent = await call(const _FailingAppCheck());
      expect(sent.requests, hasLength(1));
      expect(
        sent.requests.single.headers.containsKey('X-Firebase-AppCheck'),
        isFalse,
      );
      expect(sent.result['kind'], 'succeeded');
    },
  );

  test('the retry after a refreshed ID token carries the token too', () async {
    final sent = await call(
      const _AppCheck('app-check-token'),
      errorCodes: const ['unauthenticated'],
    );
    expect(sent.requests, hasLength(2));
    for (final request in sent.requests) {
      expect(request.headers['X-Firebase-AppCheck'], 'app-check-token');
    }
  });

  test('without a provider nothing changes (emulator and tests)', () async {
    final sent = await call(null);
    expect(sent.requests, hasLength(1));
    expect(
      sent.requests.single.headers.containsKey('X-Firebase-AppCheck'),
      isFalse,
    );
  });
}

final class _TokenProvider implements BookingFirebaseIdTokenProvider {
  const _TokenProvider(this.token);
  final String token;

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async => token;
}

final class _AppCheck implements BookingAppCheckTokenProvider {
  const _AppCheck(this.token);
  final String token;

  @override
  Future<String> currentToken({bool forceRefresh = false}) async => token;
}

final class _FailingAppCheck implements BookingAppCheckTokenProvider {
  const _FailingAppCheck();

  @override
  Future<String> currentToken({bool forceRefresh = false}) async =>
      throw StateError('play_services_unavailable');
}
