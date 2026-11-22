import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/repositories/network_status.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';

// A34 staging 2026-11-22: the network dropped in a running app, the snapshot
// was still valid, and Booking stayed enabled without a banner (decision 6).

class _Repository implements FederatedAuthRepository {
  bool reachable = true;
  bool signedIn = true;
  int restores = 0;
  int signOuts = 0;

  @override
  Future<AuthResultEntity?> restoreSession() async {
    restores++;
    if (!reachable) {
      throw const AuthException(code: 'NETWORK_UNAVAILABLE', message: '');
    }
    if (!signedIn) return null;
    return AuthResultEntity(
      session: AuthSessionEntity.serverIssued(
        sessionId: 'server',
        serverSessionHandle: 'A' * 43,
        installationId: 'install',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      user: const AuthUserEntity(
        id: 'server-user',
        email: '',
        role: 'user',
        capabilities: <String>['booking.self_service'],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<AuthResultEntity> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<AuthUserEntity?> getCurrentUser() async => null;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) => throw UnimplementedError();
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _Network implements NetworkStatus {
  final StreamController<bool> _changes = StreamController<bool>.broadcast(
    sync: true,
  );
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get changes => _changes.stream;

  void become({required bool online}) {
    this.online = online;
    _changes.add(online);
  }
}

typedef _Body =
    void Function(
      FakeAsync async,
      _Repository repository,
      _Network network,
      AuthController controller,
    );

void _run(_Body body, {bool signal = true, bool signedIn = true}) {
  fakeAsync((FakeAsync async) {
    final repository = _Repository()..signedIn = signedIn;
    final network = _Network();
    final controller = AuthController(
      signInUseCase: SignInUseCase(repository),
      restoreSessionUseCase: RestoreSessionUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      analyticsService: _Analytics(),
      signInWithGoogleUseCase: SignInWithGoogleUseCase(repository),
      networkStatus: signal ? network : null,
    );
    unawaited(controller.restoreSession());
    async.flushMicrotasks();
    body(async, repository, network, controller);
    controller.dispose();
  });
}

void main() {
  test('losing the network in a running app needs a connection at once', () {
    _run((async, repository, network, controller) {
      var notified = 0;
      controller.addListener(() => notified++);
      repository.reachable = false;
      network.become(online: false);
      async.flushMicrotasks();

      expect(controller.state.needsConnection, isTrue);
      expect(notified, greaterThan(0));
      // The server Session was not refused: nothing is signed out or wiped.
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.user?.id, 'server-user');
      expect(repository.signOuts, 0);
    });
  });

  test('a failed check on resume needs a connection inside the snapshot', () {
    _run(signal: false, (async, repository, network, controller) {
      repository.reachable = false;
      controller.suspendForBackground();
      unawaited(controller.restoreAfterBackground());
      async.flushMicrotasks();

      expect(controller.state.needsConnection, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
    });
  });

  test('the network coming back revalidates at once and clears it', () {
    _run((async, repository, network, controller) {
      repository.reachable = false;
      network.become(online: false);
      async.elapse(const Duration(seconds: 10));
      expect(controller.state.needsConnection, isTrue);
      final before = repository.restores;

      repository.reachable = true;
      network.become(online: true);
      async.flushMicrotasks();

      expect(repository.restores, before + 1);
      expect(controller.state.needsConnection, isFalse);
      expect(controller.state.isAuthenticated, isTrue);
    });
  });

  test('after the snapshot expired the network coming back signs in again', () {
    _run((async, repository, network, controller) {
      repository.reachable = false;
      network.become(online: false);
      async.elapse(const Duration(hours: 1, seconds: 10));
      expect(controller.state.isOffline, isTrue);
      final before = repository.restores;

      repository.reachable = true;
      network.become(online: true);
      async.flushMicrotasks();

      expect(repository.restores, before + 1);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.needsConnection, isFalse);
    });
  });

  test('a change missed in the background is read on resume', () {
    _run((async, repository, network, controller) {
      controller.suspendForBackground();
      // Android gives no change events to a background app.
      network.online = false;
      repository.reachable = false;
      unawaited(controller.restoreAfterBackground());
      async.flushMicrotasks();

      expect(controller.state.needsConnection, isTrue);
    });
  });

  test('a wrong "no network" signal heals when the server answers', () {
    _run((async, repository, network, controller) {
      network.become(online: false);
      async.flushMicrotasks();
      expect(controller.state.needsConnection, isTrue);

      async.elapse(const Duration(seconds: 2));

      expect(controller.state.needsConnection, isFalse);
    });
  });

  test('a network change in the background sends nothing', () {
    _run((async, repository, network, controller) {
      controller.suspendForBackground();
      final before = repository.restores;
      network.become(online: false);
      async.elapse(const Duration(minutes: 3));
      network.become(online: true);
      async.flushMicrotasks();

      expect(repository.restores, before);
    });
  });

  test('a guest without a network gets no offline state and no requests', () {
    _run(signedIn: false, (async, repository, network, controller) {
      final before = repository.restores;
      network.become(online: false);
      async.elapse(const Duration(minutes: 1));

      expect(controller.state.needsConnection, isFalse);
      expect(repository.restores, before);
    });
  });
}
