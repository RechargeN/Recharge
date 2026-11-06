import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';
import 'package:recharge/features/auth/data/repositories/dev_server_auth_repository.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';
import 'package:recharge/features/booking/data/booking_identity_failure.dart';

// Offline/Doze must not wipe the Recharge Session or the Firebase user
// (A34 cold start, 2026-11-06); server refusals still do.

class _Tokens implements BookingFirebaseIdTokenProvider {
  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async =>
      'test-id-token';
}

class _AppCheck implements BookingAppCheckTokenProvider {
  @override
  Future<String> currentToken({bool forceRefresh = false}) async =>
      'test-app-check';
}

class _Installations implements BookingInstallationIdProvider {
  @override
  Future<String> current() async => 'install-dev';
}

class _OfflineGateway implements DevAuthSessionGateway {
  int clears = 0;
  Object failure = const AuthException(
    code: offlineAuthErrorCode,
    message: offlineAuthErrorCode,
  );
  @override
  Future<ServerAuthContext?> refresh() => Future.error(failure);
  @override
  Future<ServerAuthContext?> current() => Future.error(failure);
  @override
  Future<ServerAuthContext> signInWithGoogle() => Future.error(failure);
  @override
  Future<void> clearLocal() async => clears++;
  @override
  Future<void> revokeAndSignOut() async {}
}

Future<InMemoryBookingIdentitySessionStore> _storeWithSession() async {
  final store = InMemoryBookingIdentitySessionStore();
  await store.saveServerIssued(
    BookingIdentitySessionContext(
      sessionId: 'session-server',
      sessionHandle: 'A' * 43,
      installationId: 'install-dev',
    ),
  );
  return store;
}

FunctionsIdentitySessionClient _client(
  InMemoryBookingIdentitySessionStore store,
  MockClientHandler handler,
) => FunctionsIdentitySessionClient(
  endpoint: BookingBackendEndpoint.devIdentity(
    Uri.parse('https://europe-west1-recharge-dev-n2a01.cloudfunctions.net'),
  ),
  client: MockClient(handler),
  tokens: _Tokens(),
  installations: _Installations(),
  sessions: store,
  appCheck: _AppCheck(),
  identityProvider: 'google',
);

http.Response _envelope(Map<String, Object?> result) =>
    http.Response(jsonEncode({'result': result}), 200);

void main() {
  test('classifier: only explicit refusals are terminal', () {
    for (final transient in <Object>[
      TimeoutException('t'),
      const SocketException('dns'),
      http.ClientException('connection failed'),
      FirebaseAuthException(code: 'network-request-failed'),
      FirebaseAuthException(code: 'too-many-requests'),
      const BookingCallableFailure(code: 'unavailable', dispatched: true),
      const BookingCallableFailure(code: 'deadline-exceeded', dispatched: true),
      const BookingCallableFailure(code: 'rate-limited', dispatched: true),
      const BookingCallableFailure(code: 'internal', dispatched: true),
      const BookingCallableFailure(
        code: 'temporarily-unavailable',
        dispatched: true,
      ),
      FirebaseAuthException(code: 'unknown'),
      FirebaseAuthException(code: 'internal-error'),
      PlatformException(code: 'ERROR'),
      const FormatException('Malformed Functions callable response'),
      StateError('dev_identity_operation_in_progress'),
    ]) {
      expect(
        isTransientIdentityFailure(transient),
        isTrue,
        reason: '$transient',
      );
    }
    for (final terminal in <Object>[
      FirebaseAuthException(code: 'user-disabled'),
      FirebaseAuthException(code: 'user-token-expired'),
      const BookingCallableFailure(code: 'unauthenticated', dispatched: true),
      const BookingCallableFailure(code: 'session-revoked', dispatched: true),
      const BookingCallableFailure(code: 'session-expired', dispatched: true),
      const FormatException('dev_identity_response_mismatch'),
      const FormatException('server_auth_context_invalid'),
      const BookingCallableFailure(code: 'account-blocked', dispatched: true),
      const BookingCallableFailure(
        code: 'provider-assertion-invalid',
        dispatched: true,
      ),
      StateError('dev_identity_session_composition_invalid'),
    ]) {
      expect(
        isTransientIdentityFailure(terminal),
        isFalse,
        reason: '$terminal',
      );
    }
  });

  for (final entry in <String, MockClientHandler>{
    'socket failure': (_) async => throw const SocketException('offline'),
    'http client failure': (_) async => throw http.ClientException('failed'),
    'backend 503': (_) async => http.Response(
      jsonEncode({
        'error': {'status': 'UNAVAILABLE'},
      }),
      503,
    ),
    'rate limited': (_) async => _envelope({
      'schemaVersion': 1,
      'commandType': 'refreshIdentitySession',
      'requestId': 'attempt',
      'kind': 'rejected',
      'error': {'code': 'rate_limited'},
    }),
  }.entries) {
    test('dev refresh keeps the stored Session on ${entry.key}', () async {
      final store = await _storeWithSession();
      await expectLater(
        _client(
          store,
          entry.value,
        ).refresh(requestId: 'attempt', requireExistingSession: true),
        throwsA(isA<BookingCallableFailure>()),
      );
      expect(await store.read(), isNotNull);
    });
  }

  test(
    'dev refresh still clears the Session when the server refuses it',
    () async {
      final store = await _storeWithSession();
      await expectLater(
        _client(
          store,
          (_) async => _envelope({
            'schemaVersion': 1,
            'commandType': 'refreshIdentitySession',
            'requestId': 'attempt',
            'kind': 'rejected',
            'error': {'code': 'session_revoked'},
          }),
        ).refresh(requestId: 'attempt', requireExistingSession: true),
        throwsA(isA<BookingCallableFailure>()),
      );
      expect(await store.read(), isNull);
    },
  );

  test(
    'repository keeps local credentials on the offline outcome only',
    () async {
      final gateway = _OfflineGateway();
      final repository = DevServerAuthRepository(gateway: gateway);
      await expectLater(
        repository.restoreSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            offlineAuthErrorCode,
          ),
        ),
      );
      expect(gateway.clears, 0);
      gateway.failure = StateError('revoked');
      await expectLater(
        repository.restoreSession(),
        throwsA(isA<AuthException>()),
      );
      expect(gateway.clears, 1);
    },
  );
}
