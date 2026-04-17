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
}

class _FakeAuthRepository implements AuthRepository {
  bool shouldFailLogin = false;
  bool shouldFailRestore = false;
  AuthResultEntity? _cachedResult;

  @override
  Future<AuthUserEntity?> getCurrentUser() async {
    return _cachedResult?.user;
  }

  @override
  Future<AuthResultEntity?> restoreSession() async {
    if (shouldFailRestore) {
      throw const AuthException(
        code: 'AUTH_REFRESH_EXPIRED',
        message: 'expired',
      );
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

class _FakeAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
