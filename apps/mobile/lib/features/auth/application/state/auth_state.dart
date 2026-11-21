import '../../domain/entities/auth_user_entity.dart';

/// `offline` (round 1, owner 2026-11-20): the user signed in on this phone and
/// the server Session was not refused, but it cannot be confirmed now (no
/// network, Doze). Saved screens stay; nothing grants server authority.
enum AuthStatus { guest, loading, authenticated, offline }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorCode,
    this.message,
  });

  const AuthState.guest()
    : status = AuthStatus.guest,
      user = null,
      errorCode = null,
      message = null;

  final AuthStatus status;
  final AuthUserEntity? user;
  final String? errorCode;
  final String? message;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isGuest => status == AuthStatus.guest;

  /// Signed in, but the Session cannot be confirmed right now (no network).
  bool get isOffline => status == AuthStatus.offline && user != null;

  /// Signed in on this phone: confirmed now, or offline with a kept Session.
  /// Never server authority; that stays [isAuthenticated].
  bool get isSignedIn => isAuthenticated || isOffline;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthUserEntity? user,
    String? errorCode,
    String? message,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      message: clearError ? null : (message ?? this.message),
    );
  }
}
