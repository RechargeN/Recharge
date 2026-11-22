import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';
import 'package:recharge/features/auth/data/repositories/dev_server_auth_repository.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';

// Decision 2026-11-21 #5. Booking, Content and the inbox repair the Session by
// themselves, past the auth repository. A revocation they met first cleared
// the stored Session, so the next check found none and nothing was wiped.

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

class _Gateway implements DevAuthSessionGateway {
  int clears = 0;

  @override
  Future<void> clearLocal() async => clears++;

  @override
  Future<ServerAuthContext?> current() async => null;

  @override
  Future<ServerAuthContext?> refresh() async => null;

  @override
  Future<ServerAuthContext> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> revokeAndSignOut() async {}
}

/// [callable] is the answer of the inbox query, [session] of the repair.
Future<int> _signals({
  required String callable,
  required FutureOr<http.Response> Function(http.Request) session,
}) async {
  final store = InMemoryBookingIdentitySessionStore();
  await store.saveServerIssued(
    BookingIdentitySessionContext(
      sessionId: 'session-server',
      sessionHandle: 'A' * 43,
      installationId: 'install-dev',
    ),
  );
  final endpoint = BookingBackendEndpoint.devIdentity(
    Uri.parse('https://europe-west1-recharge-dev-n2a01.cloudfunctions.net'),
  );
  final client = MockClient((request) async {
    if (request.url.path.endsWith('refreshIdentitySessionV1')) {
      return session(request);
    }
    return _rejected(request, callable);
  });
  var signals = 0;
  final port = FunctionsBookingCallablePort(
    endpoint: endpoint,
    client: client,
    tokens: _Tokens(),
    sessions: store,
    identitySessions: FunctionsIdentitySessionClient(
      endpoint: endpoint,
      client: client,
      tokens: _Tokens(),
      installations: _Installations(),
      sessions: store,
      appCheck: _AppCheck(),
      identityProvider: 'google',
    ),
    onAccessEnded: () => signals++,
  );
  try {
    await port.invoke('notificationsQueryV1', <String, Object?>{
      'schemaVersion': 1,
      'requestId': 'attempt',
    });
  } on BookingCallableFailure {
    // The caller still gets the refusal.
  }
  return signals;
}

/// Two calls in flight (a resume loads the inbox and the Library together): the
/// first repair is refused and empties the store, then the slower answer comes.
/// The token access stays on, as it does until the local clear has run.
Future<List<String>> _establishedAfter(String refusal) async {
  final store = InMemoryBookingIdentitySessionStore();
  await store.saveServerIssued(
    BookingIdentitySessionContext(
      sessionId: 'session-server',
      sessionHandle: 'A' * 43,
      installationId: 'install-dev',
    ),
  );
  final endpoint = BookingBackendEndpoint.devIdentity(
    Uri.parse('https://europe-west1-recharge-dev-n2a01.cloudfunctions.net'),
  );
  final slow = Completer<void>();
  final dispatched = Completer<void>();
  final established = <String>[];
  final client = MockClient((request) async {
    final path = request.url.path;
    if (path.contains('establish')) established.add(path);
    if (path.endsWith('mediaQueryV1')) {
      if (!dispatched.isCompleted) dispatched.complete();
      await slow.future;
    }
    return _rejected(
      request,
      path.endsWith('refreshIdentitySessionV1') ? refusal : 'session_revoked',
    );
  });
  final port = FunctionsBookingCallablePort(
    endpoint: endpoint,
    client: client,
    tokens: _Tokens(),
    sessions: store,
    identitySessions: FunctionsIdentitySessionClient(
      endpoint: endpoint,
      client: client,
      tokens: _Tokens(),
      installations: _Installations(),
      sessions: store,
      appCheck: _AppCheck(),
      identityProvider: 'google',
    ),
  );
  Future<void> call(String name) async {
    try {
      await port.invoke(name, <String, Object?>{
        'schemaVersion': 1,
        'requestId': name,
      });
    } on BookingCallableFailure {
      // Each caller still gets the refusal.
    }
  }

  final slower = call('mediaQueryV1');
  await dispatched.future;
  await call('notificationsQueryV1');
  slow.complete();
  await slower;
  return established;
}

http.Response _rejected(http.Request request, String code) {
  final data = (jsonDecode(request.body) as Map)['data'] as Map;
  return http.Response(
    jsonEncode({
      'result': {
        'schemaVersion': 1,
        'commandType': data['commandType'],
        'requestId': data['requestId'],
        'kind': 'rejected',
        'error': {'code': code},
      },
    }),
    200,
  );
}

void main() {
  for (final callable in <String>[
    'session_revoked',
    'session_refresh_required',
  ]) {
    for (final answer in <String>['session_revoked', 'account_blocked']) {
      test('$callable, then $answer from Identity ends access', () async {
        expect(
          await _signals(
            callable: callable,
            session: (request) => _rejected(request, answer),
          ),
          1,
        );
      });
    }
  }

  // The owner's scope of 2026-11-22: only revocation and blocking.
  for (final answer in <String>[
    'unauthenticated',
    'session_expired',
    'account_restricted',
    'rate_limited',
    'temporarily_unavailable',
  ]) {
    test('$answer from Identity does not end access', () async {
      expect(
        await _signals(
          callable: 'session_revoked',
          session: (request) => _rejected(request, answer),
        ),
        0,
      );
    });
  }

  test('no network during the repair does not end access', () async {
    expect(
      await _signals(
        callable: 'session_revoked',
        session: (_) => throw const SocketException('offline'),
      ),
      0,
    );
  });

  for (final refusal in <String>[
    'session_revoked',
    'account_blocked',
    'session_expired',
    'unauthenticated',
  ]) {
    test('a repair never opens a new Session after $refusal', () async {
      expect(await _establishedAfter(refusal), isEmpty);
    });
  }

  test('the repository announces it once and clears the sign-in', () async {
    final gateway = _Gateway();
    final repository = DevServerAuthRepository(gateway: gateway);
    var announced = 0;
    final subscription = repository.accessEnded.listen((_) => announced++);
    repository.endAccessFromTransport();
    await Future<void>.delayed(Duration.zero);

    expect(announced, 1);
    expect(gateway.clears, 1, reason: 'else the next sign-in is refused');
    await subscription.cancel();
  });
}
