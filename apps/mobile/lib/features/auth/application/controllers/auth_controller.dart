import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/auth_result_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/restore_session_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../state/auth_state.dart';

enum ProtectedAction {
  none,
  favorite,
  favorites,
  notifications,
  profile,
  create,
}

class AuthController extends ChangeNotifier {
  AuthController({
    required SignInUseCase signInUseCase,
    required RestoreSessionUseCase restoreSessionUseCase,
    required SignOutUseCase signOutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required AnalyticsService analyticsService,
  })  : _signInUseCase = signInUseCase,
        _restoreSessionUseCase = restoreSessionUseCase,
        _signOutUseCase = signOutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _analyticsService = analyticsService;

  final SignInUseCase _signInUseCase;
  final RestoreSessionUseCase _restoreSessionUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final AnalyticsService _analyticsService;

  AuthState _state = const AuthState.guest();
  AuthState get state => _state;

  ProtectedAction _pendingAction = ProtectedAction.none;
  String? _pendingOriginRoute;

  ProtectedAction get pendingAction => _pendingAction;
  String? get pendingOriginRoute => _pendingOriginRoute;

  void setPendingTarget({
    required ProtectedAction action,
    required String? originRoute,
  }) {
    _pendingAction = action;
    _pendingOriginRoute = originRoute;
  }

  void clearPendingTarget() {
    _pendingAction = ProtectedAction.none;
    _pendingOriginRoute = null;
  }

  void trackAuthGateViewed({
    required String sourceScreen,
    required String sourceAction,
  }) {
    _analyticsService.track(
      'auth_gate_viewed',
      params: <String, Object?>{
        'source_screen': sourceScreen,
        'source_action': sourceAction,
      },
    );
  }

  void trackGuestContinueClicked({
    required String sourceScreen,
    required String sourceAction,
  }) {
    _analyticsService.track(
      'auth_guest_continue_clicked',
      params: <String, Object?>{
        'source_screen': sourceScreen,
        'source_action': sourceAction,
      },
    );
  }

  void trackAuthScreenViewed({
    required String sourceScreen,
    required String sourceAction,
  }) {
    _analyticsService.track(
      'auth_screen_viewed',
      params: <String, Object?>{
        'source_screen': sourceScreen,
        'source_action': sourceAction,
      },
    );
  }

  Future<void> initializeCurrentUserFromCache() async {
    final user = await _getCurrentUserUseCase();
    if (user != null && !_state.isAuthenticated) {
      _setState(
        _state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearError: true,
        ),
      );
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
    required String sourceScreen,
    required String sourceAction,
  }) async {
    _analyticsService.track(
      'auth_sign_in_started',
      params: <String, Object?>{
        'source_screen': sourceScreen,
        'source_action': sourceAction,
        'auth_method': 'email_password',
      },
    );

    _setState(_state.copyWith(status: AuthStatus.loading, clearError: true));

    try {
      final result = await _signInUseCase(
        email: email,
        password: password,
        deviceName: 'Recharge Device',
        platform: defaultTargetPlatform.name,
        appVersion: '1.0.0',
      );
      _consumeAuthResult(result);
      _analyticsService.track(
        'auth_sign_in_succeeded',
        params: <String, Object?>{
          'auth_method': 'email_password',
          'user_role_before': 'guest',
          'user_role_after': result.user.role,
        },
      );
      return true;
    } on AuthException catch (e) {
      _setState(
        _state.copyWith(
          status: AuthStatus.guest,
          errorCode: e.code,
          message: _humanMessageForCode(e.code),
        ),
      );
      _analyticsService.track(
        'auth_sign_in_failed',
        params: <String, Object?>{
          'auth_method': 'email_password',
          'error_code': e.code,
          'error_group': _errorGroup(e.code),
        },
      );
      return false;
    }
  }

  Future<void> restoreSession() async {
    _analyticsService.track(
      'auth_session_restore_started',
      params: <String, Object?>{
        'had_refresh_token': true,
        'source_screen': 'splash',
      },
    );
    _setState(_state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final result = await _restoreSessionUseCase();
      if (result == null) {
        _setState(const AuthState.guest());
        return;
      }
      _consumeAuthResult(result);
      _analyticsService.track(
        'auth_session_restore_succeeded',
        params: <String, Object?>{
          'restore_result': 'success',
          'user_role_after': result.user.role,
        },
      );
    } on AuthException catch (e) {
      _setState(
        const AuthState.guest().copyWith(
          errorCode: e.code,
          message: 'Сессия истекла. Войдите снова.',
        ),
      );
      _analyticsService.track(
        'auth_session_restore_failed',
        params: <String, Object?>{
          'restore_result': 'failed',
          'error_code': e.code,
          'error_group': _errorGroup(e.code),
        },
      );
      _analyticsService.track(
        'auth_session_expired_shown',
        params: <String, Object?>{
          'source_screen': 'splash',
        },
      );
    }
  }

  Future<void> signOut() async {
    _analyticsService.track(
      'auth_sign_out_started',
      params: <String, Object?>{'source_screen': 'profile'},
    );
    try {
      await _signOutUseCase();
      _setState(const AuthState.guest());
      clearPendingTarget();
      _analyticsService.track(
        'auth_sign_out_succeeded',
        params: <String, Object?>{'result': 'success'},
      );
    } on Exception {
      // Logout offline policy: local sign-out is already success by repository.
      _setState(const AuthState.guest());
      clearPendingTarget();
      _analyticsService.track(
        'auth_sign_out_failed',
        params: <String, Object?>{
          'error_code': 'NETWORK_UNAVAILABLE',
          'error_group': 'network',
        },
      );
    }
  }

  void _consumeAuthResult(AuthResultEntity result) {
    _setState(
      AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
      ),
    );
  }

  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }

  String _errorGroup(String code) {
    if (code.startsWith('AUTH_')) return 'auth';
    if (code.startsWith('VALIDATION_')) return 'validation';
    if (code.contains('NETWORK')) return 'network';
    return 'server';
  }

  String _humanMessageForCode(String code) {
    switch (code) {
      case 'AUTH_INVALID_CREDENTIALS':
        return 'Неверный email или пароль';
      case 'AUTH_TOO_MANY_ATTEMPTS':
        return 'Слишком много попыток. Попробуйте позже';
      case 'NETWORK_UNAVAILABLE':
        return 'Нет подключения к интернету';
      default:
        return 'Не удалось выполнить вход. Попробуйте еще раз';
    }
  }
}
