import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';
import 'package:recharge/features/auth/data/repositories/dev_server_auth_repository.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/offline_account_store.dart';
import 'package:recharge/features/auth/domain/repositories/sign_out_everywhere.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';

import '../fixtures/auth/server_auth_packet.dart';

// Owner 2026-11-23 (variant B): "Sign out on all devices" in Settings. The
// server already revokes every Session of the account (`allSessions`); the
// app sends it and signs this phone out. Nothing on the phone is wiped.

class _Gateway implements DevAuthSessionGateway {
  final List<bool> revokes = <bool>[];
  int clears = 0;

  @override
  Future<ServerAuthContext?> current() => refresh();
  @override
  Future<ServerAuthContext> signInWithGoogle() async => (await refresh())!;
  @override
  Future<ServerAuthContext?> refresh() async => ServerAuthContext.fromResponse(
    packet(),
    installationId: 'dev-install',
    now: now,
  );
  @override
  Future<void> clearLocal() async => clears++;
  @override
  Future<void> revokeAndSignOut({bool allSessions = false}) async =>
      revokes.add(allSessions);
}

class _Store implements OfflineAccountStore {
  AuthUserEntity? profile;
  @override
  Future<void> saveOfflineProfile(AuthUserEntity user) async => profile = user;
  @override
  Future<AuthUserEntity?> readOfflineProfile() async => profile;
  @override
  Future<void> clearOfflineProfile() async => profile = null;
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

void main() {
  test('the repository asks the server to end every Session', () async {
    final gateway = _Gateway();
    final repository = DevServerAuthRepository(
      gateway: gateway,
      now: () => now,
    );
    expect(repository, isA<SignOutEverywhere>());

    await repository.signOutEverywhere();

    expect(gateway.revokes, <bool>[true]);
    expect(gateway.clears, greaterThanOrEqualTo(1));
  });

  test('a plain sign-out still ends only this Session', () async {
    final gateway = _Gateway();
    final repository = DevServerAuthRepository(
      gateway: gateway,
      now: () => now,
    );

    await repository.signOut();

    expect(gateway.revokes, <bool>[false]);
  });

  test('the controller signs this phone out and wipes nothing', () async {
    final gateway = _Gateway();
    final repository = DevServerAuthRepository(
      gateway: gateway,
      now: () => now,
    );
    final store = _Store();
    final controller = AuthController(
      signInUseCase: SignInUseCase(repository),
      restoreSessionUseCase: RestoreSessionUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      analyticsService: _Analytics(),
      signInWithGoogleUseCase: SignInWithGoogleUseCase(repository),
      offlineAccount: store,
      signOutEverywhere: repository,
    );
    addTearDown(controller.dispose);
    expect(controller.supportsSignOutEverywhere, isTrue);

    await controller.signOutEverywhere();

    expect(gateway.revokes, <bool>[true]);
    expect(controller.state.isGuest, isTrue);
    expect(store.profile, isNull);
  });
}
