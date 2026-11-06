import 'package:uuid/uuid.dart';
import '../../features/booking/data/booking_dev_android_identity.dart';
import '../../features/booking/data/booking_functions_transport.dart';
import '../../features/booking/data/booking_identity_failure.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/models/server_auth_context.dart';
import '../../features/auth/data/repositories/dev_server_auth_repository.dart';

/// Explicit SDK/Session bridge. Runtime must supply the separately implemented remote revoke.
final class NativeDevAuthSessionGateway implements DevAuthSessionGateway {
  NativeDevAuthSessionGateway({
    required this.coordinator,
    required this.installations,
    required this.store,
    Future<void> Function()? revokeCurrentSession,
    DateTime Function()? now,
  }) : revokeCurrentSession =
           revokeCurrentSession ??
           (() => coordinator.sessions.revoke(requestId: const Uuid().v4())),
       _now = now ?? (() => DateTime.now().toUtc()) {
    if (!coordinator.sessions.isDevGoogleFor(store, coordinator.identity)) {
      throw StateError('dev_auth_gateway_binding_invalid');
    }
  }
  final DevAndroidIdentitySessionCoordinator coordinator;
  final BookingInstallationIdProvider installations;
  final BookingIdentitySessionStore store;
  final Future<void> Function() revokeCurrentSession;
  final DateTime Function() _now;

  @override
  Future<ServerAuthContext> signInWithGoogle() async {
    ServerAuthContext? result;
    final installation = await installations.current();
    await coordinator.signInWithGoogle(
      requestId: const Uuid().v4(),
      onAuthContext: (data) {
        result = ServerAuthContext.fromResponse(
          data,
          installationId: installation,
          now: _now(),
        );
        return Future<void>.value();
      },
    );
    if (result == null) throw StateError('server_auth_context_missing');
    return result!;
  }

  /// Offline or overloaded: keep credentials, grant nothing, let Auth retry.
  static const offlineCode = 'NETWORK_UNAVAILABLE';

  Future<T> _offlineAware<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stack) {
      if (isTransientIdentityFailure(error)) {
        throw const AuthException(code: offlineCode, message: offlineCode);
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  @override
  Future<ServerAuthContext?> refresh() => _offlineAware(_refresh);

  Future<ServerAuthContext?> _refresh() async {
    if (await store.read() == null) return null;
    ServerAuthContext? result;
    final installation = await installations.current();
    final restored = await coordinator.restoreSession(
      requestId: const Uuid().v4(),
      onAuthContext: (data) {
        result = ServerAuthContext.fromResponse(
          data,
          installationId: installation,
          now: _now(),
        );
        return Future<void>.value();
      },
    );
    if (restored == null) return null;
    if (result == null) throw StateError('server_auth_context_missing');
    return result;
  }

  @override
  Future<ServerAuthContext?> current() => _offlineAware(_current);

  Future<ServerAuthContext?> _current() async {
    if (await store.read() == null ||
        await coordinator.identity.currentIdToken() == null) {
      return null;
    }
    ServerAuthContext? result;
    final installation = await installations.current();
    await coordinator.sessions.readCurrent(
      requestId: const Uuid().v4(),
      onAuthContext: (data) {
        result = ServerAuthContext.fromResponse(
          data,
          installationId: installation,
          now: _now(),
        );
        return Future<void>.value();
      },
    );
    if (result == null) throw StateError('server_auth_context_missing');
    return result;
  }

  @override
  Future<void> revokeAndSignOut() async {
    try {
      await revokeCurrentSession();
    } finally {
      await clearLocal();
    }
  }

  @override
  Future<void> clearLocal() => coordinator.identity.signOutLocal();
}
