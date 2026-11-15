import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';
import 'package:recharge/features/auth/data/repositories/dev_server_auth_repository.dart';

import '../fixtures/auth/server_auth_packet.dart';

/// N4b A34 2026-11-15 (staging): every start and every return to the app
/// rotated the Session (`refreshIdentitySessionV1`); the server allows six
/// rotations per Session per hour, so after a few app switches restore was
/// refused (`rate-limited`) and the app showed "Session expired". Restore now
/// revalidates with a read and rotates only near the snapshot expiry.
class _Gateway implements DevAuthSessionGateway {
  int currents = 0;
  int refreshes = 0;
  bool noCurrent = false;

  ServerAuthContext _context() => ServerAuthContext.fromResponse(
    packet(), // snapshot expires 2026-11-05T11:00Z
    installationId: 'dev-install',
    now: now,
  );

  @override
  Future<ServerAuthContext?> current() async {
    currents++;
    return noCurrent ? null : _context();
  }

  @override
  Future<ServerAuthContext?> refresh() async {
    refreshes++;
    return _context();
  }

  @override
  Future<ServerAuthContext> signInWithGoogle() async => _context();

  @override
  Future<void> clearLocal() async {}

  @override
  Future<void> revokeAndSignOut() async {}
}

void main() {
  test(
    'a snapshot with time left is revalidated by a read, not rotated',
    () async {
      final gateway = _Gateway();
      final repository = DevServerAuthRepository(
        gateway: gateway,
        now: () => now, // 60 min left
      );
      for (var i = 0; i < 10; i++) {
        expect(await repository.restoreSession(), isNotNull);
      }
      expect(gateway.currents, 10);
      expect(gateway.refreshes, 0);
    },
  );

  test('a snapshot close to expiry is rotated once per restore', () async {
    final gateway = _Gateway();
    final repository = DevServerAuthRepository(
      gateway: gateway,
      now: () => now.add(const Duration(minutes: 52)), // 8 min left
    );
    expect(await repository.restoreSession(), isNotNull);
    expect(gateway.currents, 1);
    expect(gateway.refreshes, 1);
    expect(
      DevServerAuthRepository.rotateWhenLessThan,
      greaterThan(const Duration(minutes: 5)),
      reason: 'the silent refresh fires 5 min before expiry and must rotate',
    );
  });

  test('no current Session falls back to the rotation path', () async {
    final gateway = _Gateway()..noCurrent = true;
    final repository = DevServerAuthRepository(
      gateway: gateway,
      now: () => now,
    );
    expect(await repository.restoreSession(), isNotNull);
    expect(gateway.refreshes, 1);
  });
}
