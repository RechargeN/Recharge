import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';

class Tokens implements BookingFirebaseIdTokenProvider {
  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async =>
      'test-id-token';
}

class AppCheck implements BookingAppCheckTokenProvider {
  String token = 'test-app-check';
  @override
  Future<String> currentToken({bool forceRefresh = false}) async => token;
}

class Installations implements BookingInstallationIdProvider {
  @override
  Future<String> current() async => 'install-dev';
}

void main() {
  final endpoint = BookingBackendEndpoint.devIdentity(
    Uri.parse('https://europe-west1-recharge-dev-n2a01.cloudfunctions.net'),
  );
  test('dev endpoint accepts only exact project and Session callables', () {
    for (final uri in [
      'http://europe-west1-recharge-dev-n2a01.cloudfunctions.net',
      'https://other.cloudfunctions.net',
      'https://europe-west1-recharge-dev-n2a01.cloudfunctions.net?target=prod',
    ]) {
      expect(
        () => BookingBackendEndpoint.devIdentity(Uri.parse(uri)),
        throwsArgumentError,
      );
    }
    // N3a.2 opens only the five Content/Media calls; delivery stays closed.
    expect(() => endpoint.callableUri('mediaDeliveryV1'), throwsArgumentError);
    expect(
      () => endpoint.callableUri('createInternalBookingV1'),
      throwsArgumentError,
    );
  });
  test(
    'requires App Check before dispatch and accepts only correlated server Session',
    () async {
      var dispatches = 0;
      final store = InMemoryBookingIdentitySessionStore();
      final check = AppCheck()..token = '';
      final client = FunctionsIdentitySessionClient(
        endpoint: endpoint,
        client: MockClient((request) async {
          dispatches++;
          expect(request.headers['Authorization'], 'Bearer test-id-token');
          expect(request.headers['X-Firebase-AppCheck'], 'test-app-check');
          expect(request.headers['X-Recharge-Identity-Provider'], 'google');
          return http.Response(
            jsonEncode({
              'result': {
                'schemaVersion': 1,
                'commandType': 'establishIdentitySession',
                'requestId': 'attempt',
                'kind': 'succeeded',
                'data': {
                  'sessionContext': {
                    'userId': 'user-server',
                    'sessionId': 'session-server',
                    'sessionHandle': 'A' * 43,
                    'installationId': 'install-dev',
                    'expiresAtUtc': DateTime.now()
                        .toUtc()
                        .add(const Duration(minutes: 30))
                        .toIso8601String(),
                  },
                },
              },
            }),
            200,
          );
        }),
        tokens: Tokens(),
        installations: Installations(),
        sessions: store,
        appCheck: check,
        identityProvider: 'google',
      );
      await expectLater(
        client.establish(requestId: 'attempt'),
        throwsA(isA<BookingCallableFailure>()),
      );
      expect(dispatches, 0);
      check.token = 'test-app-check';
      expect(
        (await client.establish(requestId: 'attempt')).sessionId,
        'session-server',
      );
      expect(dispatches, 1);
      expect((await store.read())!.toJson().containsKey('userId'), isFalse);
    },
  );
  test(
    'revoked dev refresh clears handle and never silently establishes again',
    () async {
      var dispatches = 0;
      final store = InMemoryBookingIdentitySessionStore();
      await store.saveServerIssued(
        BookingIdentitySessionContext(
          sessionId: 'session-server',
          sessionHandle: 'A' * 43,
          installationId: 'install-dev',
        ),
      );
      final client = FunctionsIdentitySessionClient(
        endpoint: endpoint,
        client: MockClient((request) async {
          dispatches++;
          expect(request.url.path, '/refreshIdentitySessionV1');
          return http.Response(
            jsonEncode({
              'result': {
                'schemaVersion': 1,
                'commandType': 'refreshIdentitySession',
                'requestId': 'attempt',
                'kind': 'rejected',
                'error': {'code': 'session_revoked'},
              },
            }),
            200,
          );
        }),
        tokens: Tokens(),
        installations: Installations(),
        sessions: store,
        appCheck: AppCheck(),
        identityProvider: 'google',
      );
      await expectLater(
        client.refresh(requestId: 'attempt'),
        throwsA(isA<BookingCallableFailure>()),
      );
      expect(dispatches, 1);
      expect(await store.read(), isNull);
    },
  );
  test(
    'wrong response request, installation and expiry are never persisted',
    () async {
      for (final invalid in ['request', 'installation', 'expiry']) {
        final store = InMemoryBookingIdentitySessionStore();
        final client = FunctionsIdentitySessionClient(
          endpoint: endpoint,
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'result': {
                  'schemaVersion': 1,
                  'commandType': 'establishIdentitySession',
                  'requestId': invalid == 'request' ? 'other' : 'attempt',
                  'kind': 'succeeded',
                  'data': {
                    'sessionContext': {
                      'userId': 'user-server',
                      'sessionId': 'session-server',
                      'sessionHandle': 'A' * 43,
                      'installationId': invalid == 'installation'
                          ? 'other'
                          : 'install-dev',
                      'expiresAtUtc': DateTime.now()
                          .toUtc()
                          .add(Duration(minutes: invalid == 'expiry' ? -1 : 30))
                          .toIso8601String(),
                    },
                  },
                },
              }),
              200,
            ),
          ),
          tokens: Tokens(),
          installations: Installations(),
          sessions: store,
          appCheck: AppCheck(),
          identityProvider: 'google',
        );
        await expectLater(
          client.establish(requestId: 'attempt'),
          throwsFormatException,
        );
        expect(await store.read(), isNull);
      }
    },
  );
  test(
    'revoke requires a correlated server acknowledgement before clearing handle',
    () async {
      for (final confirmed in [true, false]) {
        final store = InMemoryBookingIdentitySessionStore();
        await store.saveServerIssued(
          BookingIdentitySessionContext(
            sessionId: 'server-session',
            sessionHandle: 'A' * 43,
            installationId: 'install-dev',
          ),
        );
        final client = FunctionsIdentitySessionClient(
          endpoint: endpoint,
          client: MockClient((request) async {
            expect(request.url.path, '/revokeIdentitySessionV1');
            final command = (jsonDecode(request.body) as Map)['data'] as Map;
            expect(command['allSessions'], isFalse);
            return http.Response(
              jsonEncode({
                'result': {
                  'schemaVersion': 1,
                  'commandType': 'revokeIdentitySession',
                  'requestId': 'revoke',
                  'kind': 'succeeded',
                  'data': {'revoked': confirmed},
                },
              }),
              200,
            );
          }),
          tokens: Tokens(),
          installations: Installations(),
          sessions: store,
          appCheck: AppCheck(),
          identityProvider: 'google',
        );
        if (confirmed) {
          await client.revoke(requestId: 'revoke');
          expect(await store.read(), isNull);
        } else {
          await expectLater(
            client.revoke(requestId: 'revoke'),
            throwsA(isA<BookingCallableFailure>()),
          );
          expect(await store.read(), isNotNull);
        }
      }
    },
  );

  test(
    'observe mode dispatches without an App Check header; default mode refuses',
    () async {
      final headers = <Map<String, String>>[];
      final check = AppCheck()..token = '';
      FunctionsIdentitySessionClient client({required bool observe}) =>
          FunctionsIdentitySessionClient(
            endpoint: endpoint,
            client: MockClient((request) async {
              headers.add(request.headers);
              return http.Response(
                jsonEncode({
                  'result': {
                    'schemaVersion': 1,
                    'commandType': 'establishIdentitySession',
                    'requestId': 'attempt',
                    'kind': 'succeeded',
                    'data': {
                      'sessionContext': {
                        'userId': 'user-server',
                        'sessionId': 'session-server',
                        'sessionHandle': 'A' * 43,
                        'installationId': 'install-dev',
                        'expiresAtUtc': DateTime.now()
                            .toUtc()
                            .add(const Duration(minutes: 30))
                            .toIso8601String(),
                      },
                    },
                  },
                }),
                200,
              );
            }),
            tokens: Tokens(),
            installations: Installations(),
            sessions: InMemoryBookingIdentitySessionStore(),
            appCheck: check,
            identityProvider: 'google',
            observeAppCheck: observe,
          );
      await expectLater(
        client(observe: false).establish(requestId: 'attempt'),
        throwsA(isA<BookingCallableFailure>()),
      );
      expect(headers, isEmpty);
      expect(
        (await client(observe: true).establish(requestId: 'attempt')).sessionId,
        'session-server',
      );
      expect(headers.single.containsKey('x-firebase-appcheck'), isFalse);
      expect(
        headers.single['Authorization'] ?? headers.single['authorization'],
        'Bearer test-id-token',
      );
    },
  );
}
