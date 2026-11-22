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
    this.networkUnavailable = false,
  });

  const AuthState.guest()
    : status = AuthStatus.guest,
      user = null,
      errorCode = null,
      message = null,
      networkUnavailable = false;

  final AuthStatus status;
  final AuthUserEntity? user;
  final String? errorCode;
  final String? message;

  /// OFFLINE-01: the phone has no network or the last Session check could not
  /// reach the server. Independent of [status]: authority is neither granted
  /// nor ended by it.
  final bool networkUnavailable;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isGuest => status == AuthStatus.guest;

  /// Signed in, but the Session cannot be confirmed right now (no network).
  bool get isOffline => status == AuthStatus.offline && user != null;

  /// Signed in on this phone: confirmed now, or offline with a kept Session.
  /// Never server authority; that stays [isAuthenticated].
  bool get isSignedIn => isAuthenticated || isOffline;

  /// Owner decision 2026-11-21 #6: the banner and the disabled server actions.
  /// True as soon as the network is gone, also inside a valid snapshot.
  bool get needsConnection =>
      isOffline || (isAuthenticated && networkUnavailable);
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthUserEntity? user,
    String? errorCode,
    String? message,
    bool? networkUnavailable,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      message: clearError ? null : (message ?? this.message),
      networkUnavailable: networkUnavailable ?? this.networkUnavailable,
    );
  }
}
