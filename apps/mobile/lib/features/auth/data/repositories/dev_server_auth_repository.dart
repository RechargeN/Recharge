import '../../domain/entities/auth_result_entity.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/server_auth_context.dart';

/// Implement through the existing SDK/Session transport, including remote revoke.
abstract interface class DevAuthSessionGateway {
  Future<ServerAuthContext> signInWithGoogle();
  Future<ServerAuthContext?> refresh();
  Future<ServerAuthContext?> current();
  Future<void> revokeAndSignOut();
  Future<void> clearLocal();
}

/// No demo authority, no persisted permission cache, no fabricated bearer tokens.
final class DevServerAuthRepository implements FederatedAuthRepository {
  DevServerAuthRepository({required this.gateway, DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());
  final DevAuthSessionGateway gateway;
  final DateTime Function() _now;
  bool _busy = false;
  bool _signingOut = false;
  int _generation = 0;

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    throw const AuthException(
      code: 'password_auth_disabled',
      message: 'password_auth_disabled',
    );
  }

  @override
  Future<AuthResultEntity> signInWithGoogle() async {
    final context = await _run(gateway.signInWithGoogle);
    final result = context?.result;
    if (result == null) {
      throw const AuthException(
        code: 'unauthenticated',
        message: 'unauthenticated',
      );
    }
    return result;
  }

  @override
  Future<AuthResultEntity?> restoreSession() async =>
      (await _run(gateway.refresh))?.result;

  Future<ServerAuthContext?> revalidateContext() => _run(gateway.current);

  @override
  Future<AuthUserEntity?> getCurrentUser() async =>
      (await revalidateContext())?.result.user;

  Future<ServerAuthContext?> _run(
    Future<ServerAuthContext?> Function() operation,
  ) async {
    if (_busy || _signingOut) {
      throw const AuthException(
        code: 'auth_operation_in_progress',
        message: 'auth_operation_in_progress',
      );
    }
    _busy = true;
    final generation = _generation;
    try {
      final context = await operation();
      if (generation != _generation ||
          (context != null &&
              !context.result.session.expiresAtUtc.isAfter(_now().toUtc()))) {
        throw const AuthException(
          code: 'unauthenticated',
          message: 'unauthenticated',
        );
      }
      return context;
    } catch (error, stack) {
      try {
        await gateway.clearLocal();
      } catch (_) {
        /* Never grant authority on cleanup failure. */
      }
      if (error is AuthException) {
        Error.throwWithStackTrace(error, stack);
      }
      throw const AuthException(
        code: 'unauthenticated',
        message: 'unauthenticated',
      );
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> signOut() async {
    if (_signingOut) {
      throw const AuthException(
        code: 'auth_operation_in_progress',
        message: 'auth_operation_in_progress',
      );
    }
    _signingOut = true;
    _generation++;
    try {
      await gateway.revokeAndSignOut();
    } finally {
      try {
        await gateway.clearLocal();
      } finally {
        _signingOut = false;
      }
    }
  }
}
