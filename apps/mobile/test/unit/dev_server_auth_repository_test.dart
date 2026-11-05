import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';
import 'package:recharge/features/auth/data/repositories/dev_server_auth_repository.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';

import '../fixtures/auth/server_auth_packet.dart';

ServerAuthContext context([Map<String, Object?>? data]) =>
    ServerAuthContext.fromResponse(
      data ?? packet(),
      installationId: 'dev-install',
      now: now,
    );

class Gateway implements DevAuthSessionGateway {
  int clears = 0;
  int refreshes = 0;
  bool reject = false;
  Completer<ServerAuthContext>? pending;
  Completer<void>? logout;
  @override
  Future<ServerAuthContext?> current() => refresh();
  @override
  Future<ServerAuthContext> signInWithGoogle() =>
      pending?.future ?? Future.value(context());
  @override
  Future<ServerAuthContext?> refresh() {
    refreshes++;
    return reject
        ? Future.error(StateError('revoked'))
        : Future.value(context());
  }

  @override
  Future<void> clearLocal() async {
    clears++;
  }

  @override
  Future<void> revokeAndSignOut() => logout?.future ?? Future<void>.value();
}

void main() {
  test(
    'server projection maps only server roles/capabilities, never fabricates tokens',
    () {
      final result = context().result;
      expect(result.user.id, '018FQ2Z8Q9N4M7K2T6V3W1X5YA');
      expect(result.user.role, 'user');
      expect(result.user.capabilities, ['booking.self_service']);
      expect(result.session.accessToken, isNull);
      expect(result.session.refreshToken, isNull);
      expect(result.session.serverSessionHandle, 'A' * 43);
      expect(
        () => result.user.capabilities.add('admin.tools.view'),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'mismatched, expired, page-scoped and forward authority is rejected',
    () {
      for (final field in [
        'userId',
        'sessionId',
        'expiresAtUtc',
        'schemaVersion',
        'pageId',
        'accountRevision',
      ]) {
        final data = packet();
        final auth = data['authContext'] as Map;
        final snapshot = auth['accessSnapshot'] as Map;
        snapshot[field] = switch (field) {
          'schemaVersion' => 2,
          'accountRevision' => -1,
          'expiresAtUtc' => '2026-11-05T09:00:00.000Z',
          _ => 'other',
        };
        expect(() => context(data), throwsFormatException, reason: field);
      }
      final data = packet();
      ((data['authContext'] as Map)['profile'] as Map)['systemRoles'] = [
        'Admin',
      ];
      expect(() => context(data), throwsFormatException);
    },
  );
  test(
    'schema boundaries: zero revision is valid; invalid ids, capabilities and UTC dates deny',
    () {
      final zero = packet();
      ((zero['authContext'] as Map)['accessSnapshot']
              as Map)['accountRevision'] =
          0;
      expect(context(zero).result.user.role, 'user');
      for (final invalid in ['id', 'capability', 'calendar', 'offset']) {
        final data = packet();
        final auth = data['authContext'] as Map;
        final snapshot = auth['accessSnapshot'] as Map;
        final session = data['sessionContext'] as Map;
        if (invalid == 'id') {
          session['userId'] = 'invalid';
          snapshot['userId'] = 'invalid';
          (auth['profile'] as Map)['userId'] = 'invalid';
        } else if (invalid == 'capability') {
          snapshot['capabilityIds'] = ['admin:tools'];
        } else {
          final date = invalid == 'calendar'
              ? '2027-02-31T11:00:00.000Z'
              : '2027-02-28T11:00:00.000+00:00';
          session['expiresAtUtc'] = date;
          snapshot['expiresAtUtc'] = date;
        }
        expect(() => context(data), throwsFormatException, reason: invalid);
      }
    },
  );

  test(
    'each restore/current user revalidates server and rejection never restores cached grants',
    () async {
      final gateway = Gateway();
      final repository = DevServerAuthRepository(
        gateway: gateway,
        now: () => now,
      );
      expect((await repository.signInWithGoogle()).user.role, 'user');
      expect(
        (await repository.getCurrentUser())!.id,
        '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
      );
      expect(gateway.refreshes, 1);
      gateway.reject = true;
      await expectLater(
        repository.restoreSession(),
        throwsA(isA<AuthException>()),
      );
      expect(gateway.clears, 1);
      await expectLater(
        repository.signIn(
          email: 'a',
          password: 'b',
          deviceName: 'd',
          platform: 'android',
          appVersion: '1',
        ),
        throwsA(isA<AuthException>()),
      );
    },
  );
  test('logout fences an in-flight login and concurrent restore', () async {
    final gateway = Gateway()..pending = Completer<ServerAuthContext>();
    final repository = DevServerAuthRepository(
      gateway: gateway,
      now: () => now,
    );
    final login = repository.signInWithGoogle();
    final denied = expectLater(login, throwsA(isA<AuthException>()));
    await expectLater(
      repository.restoreSession(),
      throwsA(isA<AuthException>()),
    );
    await repository.signOut();
    gateway.pending!.complete(context());
    await denied;
    expect(gateway.clears, greaterThanOrEqualTo(2));
  });
  test(
    'new login is blocked until pending remote logout and cleanup finish',
    () async {
      final gateway = Gateway()..logout = Completer<void>();
      final repository = DevServerAuthRepository(
        gateway: gateway,
        now: () => now,
      );
      final logout = repository.signOut();
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthException>()),
      );
      gateway.logout!.complete();
      await logout;
      expect((await repository.signInWithGoogle()).user.role, 'user');
    },
  );
  test(
    'repository rejects a projection that expired while the request completed',
    () async {
      final gateway = Gateway();
      final repository = DevServerAuthRepository(
        gateway: gateway,
        now: () => now.add(const Duration(hours: 2)),
      );
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthException>()),
      );
      expect(gateway.clears, 1);
    },
  );
}
