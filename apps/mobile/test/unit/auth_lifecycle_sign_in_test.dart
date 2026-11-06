import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/auth_lifecycle_boundary.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
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

// Regression for the first A34 dev sign-in (2026-11-06): the Google account
// picker sends the app to `inactive`; suspending/restoring then discarded the
// fresh server Session and showed "session expired" before sign-in finished.

AuthResultEntity _serverResult() => AuthResultEntity(
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
    capabilities: ['booking.self_service'],
    profileStatus: 'active',
  ),
);

class _HeldFederatedRepository implements FederatedAuthRepository {
  final signInGate = Completer<AuthResultEntity>();
  Completer<void>? restoreGate;
  bool busy = false;
  int restoreCalls = 0;
  AuthResultEntity? current;

  @override
  Future<AuthResultEntity> signInWithGoogle() async {
    if (busy) {
      throw const AuthException(
        code: 'auth_operation_in_progress',
        message: '',
      );
    }
    final result = await signInGate.future;
    current = result;
    return result;
  }

  @override
  Future<AuthResultEntity?> restoreSession() async {
    restoreCalls++;
    final gate = restoreGate;
    if (gate != null) {
      busy = true;
      await gate.future;
      busy = false;
    }
    return current;
  }

  @override
  Future<AuthUserEntity?> getCurrentUser() async => current?.user;

  @override
  Future<void> signOut() async => current = null;

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

AuthController _controller(_HeldFederatedRepository repo) => AuthController(
  signInUseCase: SignInUseCase(repo),
  restoreSessionUseCase: RestoreSessionUseCase(repo),
  signOutUseCase: SignOutUseCase(repo),
  getCurrentUserUseCase: GetCurrentUserUseCase(repo),
  analyticsService: _Analytics(),
  signInWithGoogleUseCase: SignInWithGoogleUseCase(repo),
);

void main() {
  test(
    'background hooks never discard an in-progress Google sign-in',
    () async {
      final repo = _HeldFederatedRepository();
      final controller = _controller(repo);
      final signIn = controller.signInWithGoogle();
      expect(controller.isSignInInProgress, isTrue);
      controller.suspendForBackground();
      await controller.restoreAfterBackground();
      expect(repo.restoreCalls, 0);
      repo.signInGate.complete(_serverResult());
      expect(await signIn, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.message, isNull);
      expect(controller.isSignInInProgress, isFalse);
      controller.dispose();
    },
  );

  test(
    'after sign-in, backgrounding keeps the sign-in and revalidates on resume',
    () async {
      final repo = _HeldFederatedRepository();
      final controller = _controller(repo);
      final signIn = controller.signInWithGoogle();
      repo.signInGate.complete(_serverResult());
      await signIn;
      controller.suspendForBackground();
      expect(controller.state.isAuthenticated, isTrue);
      await controller.restoreAfterBackground();
      expect(repo.restoreCalls, 1);
      expect(controller.state.isAuthenticated, isTrue);
      controller.dispose();
    },
  );

  testWidgets(
    'boundary ignores transient inactive/hidden, revalidates only after paused',
    (tester) async {
      final repo = _HeldFederatedRepository();
      final controller = _controller(repo);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith((ref) => controller)],
          child: const AuthLifecycleBoundary(child: SizedBox()),
        ),
      );
      final signIn = controller.signInWithGoogle();
      // Account picker over the app.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      repo.signInGate.complete(_serverResult());
      await tester.pump();
      expect(await signIn, isTrue);
      expect(repo.restoreCalls, 0);
      expect(controller.state.isAuthenticated, isTrue);
      // Real backgrounding (e.g. opening the mail app) and coming back.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(controller.state.isAuthenticated, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repo.restoreCalls, 1);
      expect(controller.state.isAuthenticated, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'a tap during startup restore waits for it instead of failing',
    () async {
      final repo = _HeldFederatedRepository()..restoreGate = Completer<void>();
      final controller = _controller(repo);
      final restore = controller.restoreSession();
      final signIn = controller.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);
      repo.restoreGate!.complete();
      await restore;
      repo.signInGate.complete(_serverResult());
      expect(await signIn, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.errorCode, isNull);
      controller.dispose();
    },
  );
}
