import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';

// Instagram-class persistence (2026-11-06): offline/Doze never signs the user
// out; the snapshot is refreshed silently; only server refusals end sign-in.

AuthResultEntity _result(DateTime now, Duration lifetime) => AuthResultEntity(
  session: AuthSessionEntity.serverIssued(
    sessionId: 'server',
    serverSessionHandle: 'A' * 43,
    installationId: 'install',
    expiresAtUtc: now.toUtc().add(lifetime),
  ),
  user: const AuthUserEntity(
    id: 'server-user',
    email: '',
    role: 'user',
    capabilities: ['booking.self_service'],
    profileStatus: 'active',
  ),
);

class _ScriptedRepository implements FederatedAuthRepository {
  _ScriptedRepository(this.clock);
  final DateTime Function() clock;
  final List<Object> restoreScript =
      <Object>[]; // 'offline' | 'refused' | Duration
  int restoreCalls = 0;
  int signOuts = 0;

  @override
  Future<AuthResultEntity?> restoreSession() async {
    restoreCalls++;
    final step = restoreScript.isEmpty ? 'offline' : restoreScript.removeAt(0);
    if (step == 'offline') {
      throw const AuthException(code: 'NETWORK_UNAVAILABLE', message: '');
    }
    if (step == 'refused') {
      throw const AuthException(code: 'unauthenticated', message: '');
    }
    return _result(clock(), step as Duration);
  }

  bool cancelSignIn = false;
  int freshSignIns = 0;

  @override
  Future<AuthResultEntity> signInWithGoogle() async {
    if (cancelSignIn) {
      throw const AuthException(code: 'auth_cancelled', message: '');
    }
    freshSignIns++;
    return _result(clock(), const Duration(hours: 1));
  }

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
  }) => throw const AuthException(code: 'password_auth_disabled', message: '');
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

AuthController _controller(_ScriptedRepository repo) => AuthController(
  signInUseCase: SignInUseCase(repo),
  restoreSessionUseCase: RestoreSessionUseCase(repo),
  signOutUseCase: SignOutUseCase(repo),
  getCurrentUserUseCase: GetCurrentUserUseCase(repo),
  analyticsService: _Analytics(),
  signInWithGoogleUseCase: SignInWithGoogleUseCase(repo),
);

void main() {
  test(
    'offline cold start shows no-connection, keeps credentials and signs in when the network returns',
    () {
      fakeAsync((async) {
        final repo = _ScriptedRepository(DateTime.now);
        repo.restoreScript.addAll(<Object>[
          'offline',
          'offline',
          const Duration(hours: 1),
        ]);
        final controller = _controller(repo);
        unawaited(controller.restoreSession());
        async.flushMicrotasks();
        expect(controller.state.isAuthenticated, isFalse);
        expect(controller.state.message, AuthController.offlineMessage);
        expect(
          controller.state.message,
          isNot(AuthController.sessionExpiredMessage),
        );
        expect(repo.signOuts, 0);
        async.elapse(const Duration(seconds: 2)); // retry 1: still offline
        expect(repo.restoreCalls, 2);
        async.elapse(const Duration(seconds: 5)); // retry 2: network back
        expect(repo.restoreCalls, 3);
        expect(controller.state.isAuthenticated, isTrue);
        expect(controller.state.message, isNull);
        controller.dispose();
      });
    },
  );

  test('returning from a long offline sleep retries after 2 s, not 60 s', () {
    fakeAsync((async) {
      final repo = _ScriptedRepository(DateTime.now);
      final controller = _controller(repo);
      unawaited(controller.restoreSession());
      // Asleep offline: the backoff climbs to its 60 s cap.
      async.elapse(const Duration(minutes: 10));
      final asleep = repo.restoreCalls;
      controller.suspendForBackground();
      // Resume before Wi-Fi is back, then the network returns.
      repo.restoreScript.addAll(<Object>['offline', const Duration(hours: 1)]);
      unawaited(controller.restoreAfterBackground());
      async.flushMicrotasks();
      expect(repo.restoreCalls, asleep + 1);
      expect(controller.state.isAuthenticated, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(repo.restoreCalls, asleep + 2);
      expect(controller.state.isAuthenticated, isTrue);
      controller.dispose();
    });
  });

  test('an active user is refreshed silently before the snapshot expires', () {
    fakeAsync((async) {
      final repo = _ScriptedRepository(DateTime.now);
      final controller = _controller(repo);
      unawaited(controller.signInWithGoogle());
      async.flushMicrotasks();
      for (var i = 0; i < 6; i++) {
        repo.restoreScript.add(const Duration(hours: 1));
      }
      var everSignedOut = false;
      controller.addListener(() {
        if (!controller.state.isAuthenticated) everSignedOut = true;
      });
      async.elapse(const Duration(hours: 5));
      expect(controller.state.isAuthenticated, isTrue);
      expect(
        everSignedOut,
        isFalse,
        reason: 'silent refresh must not flicker to guest',
      );
      expect(repo.restoreCalls, greaterThanOrEqualTo(5));
      controller.dispose();
    });
  });

  test(
    'offline during the session keeps the UI until expiry, then retries without "session expired"',
    () {
      fakeAsync((async) {
        final repo = _ScriptedRepository(DateTime.now);
        final controller = _controller(repo);
        unawaited(controller.signInWithGoogle());
        async.flushMicrotasks();
        async.elapse(
          const Duration(minutes: 56),
        ); // silent refresh fails offline
        expect(controller.state.isAuthenticated, isTrue);
        async.elapse(
          const Duration(minutes: 10),
        ); // snapshot over, still offline
        expect(controller.state.isAuthenticated, isFalse);
        expect(controller.state.message, AuthController.offlineMessage);
        expect(repo.signOuts, 0);
        repo.restoreScript.add(const Duration(hours: 1));
        async.elapse(const Duration(minutes: 2));
        expect(controller.state.isAuthenticated, isTrue);
        controller.dispose();
      });
    },
  );

  test('a server refusal still ends the sign-in and stops retrying', () {
    fakeAsync((async) {
      final repo = _ScriptedRepository(DateTime.now);
      repo.restoreScript.add('refused');
      final controller = _controller(repo);
      unawaited(controller.restoreSession());
      async.flushMicrotasks();
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.message, AuthController.sessionExpiredMessage);
      async.elapse(const Duration(minutes: 10));
      expect(repo.restoreCalls, 1, reason: 'no retries after a refusal');
      controller.dispose();
    });
  });

  test('sign-out cancels pending offline retries', () {
    fakeAsync((async) {
      final repo = _ScriptedRepository(DateTime.now);
      final controller = _controller(repo);
      unawaited(controller.restoreSession());
      async.flushMicrotasks();
      unawaited(controller.signOut());
      async.flushMicrotasks();
      final calls = repo.restoreCalls;
      async.elapse(const Duration(minutes: 10));
      expect(repo.restoreCalls, calls);
      controller.dispose();
    });
  });

  test('closing the Google picker returns to guest without an error', () async {
    final repo = _ScriptedRepository(DateTime.now)..cancelSignIn = true;
    final controller = _controller(repo);
    expect(await controller.signInWithGoogle(), isFalse);
    expect(controller.state.isAuthenticated, isFalse);
    expect(controller.state.message, isNull);
    expect(controller.state.errorCode, isNull);
    controller.dispose();
  });

  test(
    'tapping sign-in while offline resumes kept credentials instead of a fresh sign-in',
    () {
      fakeAsync((async) {
        final repo = _ScriptedRepository(DateTime.now);
        repo.restoreScript.addAll(<Object>[
          'offline',
          'offline',
          const Duration(hours: 1),
        ]);
        final controller = _controller(repo);
        unawaited(controller.restoreSession());
        async.flushMicrotasks();
        expect(controller.state.message, AuthController.offlineMessage);
        bool? first;
        controller.signInWithGoogle().then((v) => first = v);
        async.flushMicrotasks();
        expect(
          first,
          isFalse,
        ); // still offline: nothing wiped, no Google picker
        expect(repo.freshSignIns, 0);
        expect(repo.signOuts, 0);
        bool? second;
        controller.signInWithGoogle().then((v) => second = v);
        async.flushMicrotasks();
        expect(second, isTrue); // network back: resumed without a new sign-in
        expect(repo.freshSignIns, 0);
        expect(controller.state.isAuthenticated, isTrue);
        controller.dispose();
      });
    },
  );

  test('after a server refusal the button starts a fresh Google sign-in', () {
    fakeAsync((async) {
      final repo = _ScriptedRepository(DateTime.now);
      repo.restoreScript.addAll(<Object>['offline', 'refused']);
      final controller = _controller(repo);
      unawaited(controller.restoreSession());
      async.flushMicrotasks();
      bool? result;
      controller.signInWithGoogle().then((v) => result = v);
      async.flushMicrotasks();
      expect(result, isTrue);
      expect(repo.freshSignIns, 1);
      expect(controller.state.isAuthenticated, isTrue);
      controller.dispose();
    });
  });
}
