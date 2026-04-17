import '../../domain/entities/auth_user_entity.dart';

enum AuthStatus {
  guest,
  loading,
  authenticated,
}

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

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isGuest => status == AuthStatus.guest;
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
