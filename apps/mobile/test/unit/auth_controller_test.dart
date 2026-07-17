import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/application/state/auth_state.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';

void main() {
  late _FakeAuthRepository repository;
  late AuthController controller;

  setUp(() {
    repository = _FakeAuthRepository();
    controller = AuthController(
      signInUseCase: SignInUseCase(repository),
      restoreSessionUseCase: RestoreSessionUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      analyticsService: _FakeAnalyticsService(),
    );
  });

  test('signIn success -> authenticated', () async {
    final success = await controller.signIn(
      email: 'user@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'submit',
    );

    expect(success, isTrue);
    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.email, 'user@example.com');
  });

  test('signIn fail -> guest with message', () async {
    repository.shouldFailLogin = true;
    final success = await controller.signIn(
      email: 'user@example.com',
      password: 'wrong',
      sourceScreen: 'test',
      sourceAction: 'submit',
    );

    expect(success, isFalse);
    expect(controller.state.status, AuthStatus.guest);
    expect(controller.state.errorCode, 'AUTH_INVALID_CREDENTIALS');
  });

  test('restore fail -> guest and session expired message', () async {
    repository.shouldFailRestore = true;

    await controller.restoreSession();

    expect(controller.state.status, AuthStatus.guest);
    expect(controller.state.message, contains('Сессия истекла'));
  });

  test('restoreSession reuses in-flight restore request', () async {
    repository.restoreCompleter = Completer<AuthResultEntity?>();

    final firstRestore = controller.restoreSession();
    final secondRestore = controller.restoreSession();

    expect(repository.restoreCalls, 1);

    repository.restoreCompleter!.complete(_demoAuthResult());
    await Future.wait(<Future<void>>[firstRestore, secondRestore]);

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.id, 'demo_full_access');
  });

  test('signOut keeps restored demo session when repository provides it', () async {
    await controller.signIn(
      email: 'user@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'submit',
    );
    repository.restoreDemoWhenEmpty = true;

    await controller.signOut();

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.id, 'demo_full_access');
    expect(controller.state.user?.role, 'creator');
  });
}

class _FakeAuthRepository implements AuthRepository {
  bool shouldFailLogin = false;
  bool shouldFailRestore = false;
  bool restoreDemoWhenEmpty = false;
  int restoreCalls = 0;
  Completer<AuthResultEntity?>? restoreCompleter;
  AuthResultEntity? _cachedResult;

  @override
  Future<AuthUserEntity?> getCurrentUser() async {
    return _cachedResult?.user;
  }

  @override
  Future<AuthResultEntity?> restoreSession() async {
    restoreCalls += 1;
    final completer = restoreCompleter;
    if (completer != null) {
      return completer.future;
    }
    if (shouldFailRestore) {
      throw const AuthException(
        code: 'AUTH_REFRESH_EXPIRED',
        message: 'expired',
      );
    }
    if (_cachedResult == null && restoreDemoWhenEmpty) {
      _cachedResult = _demoAuthResult();
    }
    return _cachedResult;
  }

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    if (shouldFailLogin) {
      throw const AuthException(
        code: 'AUTH_INVALID_CREDENTIALS',
        message: 'invalid',
      );
    }
    final result = AuthResultEntity(
      session: AuthSessionEntity(
        accessToken: 'acc',
        refreshToken: 'ref',
        sessionId: 'sess',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      user: const AuthUserEntity(
        id: 'usr_1',
        email: 'user@example.com',
        role: 'user',
        capabilities: <String>['discover.read'],
        profileStatus: 'active',
      ),
    );
    _cachedResult = result;
    return result;
  }

  @override
  Future<void> signOut() async {
    _cachedResult = null;
  }
}

AuthResultEntity _demoAuthResult() {
  return AuthResultEntity(
    session: AuthSessionEntity(
      accessToken: 'acc_demo',
      refreshToken: 'ref_demo',
      sessionId: 'sess_demo',
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    ),
    user: const AuthUserEntity(
      id: 'demo_full_access',
      email: 'demo@recharge.local',
      role: 'creator',
      capabilities: <String>[
        'discover.read',
        'favorites.write',
        'create.event',
        'create.place',
        'scenario.generate',
      ],
      profileStatus: 'active',
    ),
  );
}

class _FakeAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
