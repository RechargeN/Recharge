import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// The server's own answer "Session revoked" or "account blocked".
const String accessEndedAuthErrorCode = 'ACCESS_ENDED';

/// No demo authority, no persisted permission cache, no fabricated bearer tokens.
/// Auth code for transient (offline/overloaded) outcomes: credentials stay.
const String offlineAuthErrorCode = 'NETWORK_UNAVAILABLE';

/// Auth code for a server rate limit: transient as well, credentials stay.
const String rateLimitedAuthErrorCode = 'AUTH_TOO_MANY_ATTEMPTS';

/// A read found the server snapshot run out (no rotation within its hour).
/// Not a decision about the Session: credentials stay and restore rotates.
const String staleSnapshotAuthErrorCode = 'SNAPSHOT_STALE';

final class DevServerAuthRepository implements FederatedAuthRepository {
  DevServerAuthRepository({required this.gateway, DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());
  final DevAuthSessionGateway gateway;
  final DateTime Function() _now;
  bool _busy = false;
  bool _signingOut = false;
  int _generation = 0;

  /// Sync: listeners still know the account when they hear it.
  final StreamController<void> _accessEnded = StreamController<void>.broadcast(
    sync: true,
  );

  /// Raised here, not where restore is awaited: whichever call meets the
  /// refusal first (often the router's revalidation) clears the Session, and
  /// the next restore would only find that there is none.
  Stream<void> get accessEnded => _accessEnded.stream;

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

  /// Rotation threshold of a restore. Above the controller's silent-refresh
  /// lead (5 min), so the timer that fires before expiry still rotates.
  static const Duration rotateWhenLessThan = Duration(minutes: 10);

  /// Every start and every return to the app revalidates with the server. A
  /// read is enough while the snapshot has time left; rotating each time spent
  /// the server's per-Session rotation budget (6/h) and a few app switches
  /// ended in a refusal (N4b, A34 staging 2026-11-15).
  @override
  Future<AuthResultEntity?> restoreSession() async =>
      (await _run(_currentOrRotate))?.result;

  Future<ServerAuthContext?> _currentOrRotate() async {
    ServerAuthContext? current;
    try {
      current = await gateway.current();
    } on AuthException catch (error) {
      if (error.code != staleSnapshotAuthErrorCode) rethrow;
    }
    if (current != null &&
        current.result.session.expiresAtUtc.difference(_now().toUtc()) >
            rotateWhenLessThan) {
      return current;
    }
    return gateway.refresh();
  }

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
      if (kDebugMode) {
        // Type and our own constant code only; never messages, tokens or ids.
        // A FormatException message is printed only when it is one of our own
        // short constant codes (A34/emulator sign-in loss, 2026-11-18).
        final formatCode =
            error is FormatException &&
                RegExp(r'^[A-Za-z_ -]{1,64}$').hasMatch(error.message)
            ? error.message
            : '';
        final code = error is AuthException ? error.code : formatCode;
        debugPrint(
          'recharge-auth: dev operation failed type=${error.runtimeType} $code',
        );
      }
      final offline =
          error is AuthException &&
          (error.code == offlineAuthErrorCode ||
              error.code == rateLimitedAuthErrorCode ||
              error.code == staleSnapshotAuthErrorCode);
      if (error is AuthException && error.code == accessEndedAuthErrorCode) {
        _accessEnded.add(null);
      }
      if (!offline) {
        try {
          await gateway.clearLocal();
        } catch (_) {
          /* Never grant authority on cleanup failure. */
        }
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
