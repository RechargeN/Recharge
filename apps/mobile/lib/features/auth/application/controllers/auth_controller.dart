import '../../domain/repositories/auth_session_events.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/product_analytics/product_analytics_recorder.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/auth_result_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/restore_session_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_in_with_google_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../state/auth_state.dart';

enum ProtectedAction {
  none,
  favorite,
  favorites,
  notifications,
  profile,
  create,
  report,
  visit,
}

class AuthController extends ChangeNotifier {
  /// L4: stable message code of a failed session restore; the UI localizes it.
  static const String sessionExpiredMessage = 'session_expired';

  /// Transient outcome (offline, Doze, overloaded backend): credentials are
  /// kept, no authority is granted, and the controller retries by itself.
  static const String offlineMessage = 'NETWORK_UNAVAILABLE';

  /// The user closed the provider picker; shown as no error at all.
  static const String cancelledCode = 'auth_cancelled';

  /// Backoff of automatic re-validation while offline.
  static const List<Duration> offlineRetryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  /// Silent refresh happens this long before the server snapshot expires
  /// (at most a fifth of its lifetime), so an active user never sees expiry.
  static const Duration silentRefreshLead = Duration(minutes: 5);

  AuthController({
    required SignInUseCase signInUseCase,
    required RestoreSessionUseCase restoreSessionUseCase,
    required SignOutUseCase signOutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required AnalyticsService analyticsService,
    ProductAnalyticsRecorder? productAnalytics,
    SignInWithGoogleUseCase? signInWithGoogleUseCase,
    AuthSessionEvents? sessionEvents,
  }) : _signInWithGoogleUseCase = signInWithGoogleUseCase,
       _signInUseCase = signInUseCase,
       _restoreSessionUseCase = restoreSessionUseCase,
       _signOutUseCase = signOutUseCase,
       _getCurrentUserUseCase = getCurrentUserUseCase,
       _analyticsService = analyticsService,
       _productAnalytics = productAnalytics {
    _sessionSubscription = sessionEvents?.invalidated.listen((_) {
      suspendServerAuthority();
      unawaited(_signOutUseCase().catchError((Object _) {}));
    });
  }

  final SignInWithGoogleUseCase? _signInWithGoogleUseCase;
  bool get supportsGoogleSignIn => _signInWithGoogleUseCase != null;
  Timer? _serverExpiry;
  Timer? _silentRefresh;
  Timer? _offlineRetry;
  int _offlineAttempt = 0;
  StreamSubscription<void>? _sessionSubscription;
  int _generation = 0;
  bool _federatedSignInInProgress = false;

  /// True while a user-initiated Google sign-in (including its system
  /// account picker) is running.
  bool get isSignInInProgress => _federatedSignInInProgress;
  final SignInUseCase _signInUseCase;
  final RestoreSessionUseCase _restoreSessionUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final AnalyticsService _analyticsService;
  final ProductAnalyticsRecorder? _productAnalytics;

  AuthState _state = const AuthState.guest();
  AuthState get state => _state;

  Future<void>? _restoreSessionFuture;

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
    if (supportsGoogleSignIn) {
      await restoreSession();
      return;
    }
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
        deviceName:
            'Recharge Device', // l10n-ignore: device label sent to the auth backend, not UI
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
          message: e.code,
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

  void suspendServerAuthority() {
    if (!supportsGoogleSignIn) return;
    _generation++;
    _serverExpiry?.cancel();
    _cancelBackgroundRevalidation();
    clearPendingTarget();
    _setState(const AuthState.guest());
  }

  /// App moved to the background (not a transient system overlay). Like
  /// Instagram-class apps the user stays signed in: UI authority still ends at
  /// the server snapshot expiry, every server call is still checked, and the
  /// return to the foreground revalidates. Pending retries wait for resume.
  void suspendForBackground() {
    if (_federatedSignInInProgress) return;
    _offlineRetry?.cancel();
  }

  /// Returning from the background revalidates with the server; skipped while
  /// a sign-in is still completing (its own result is fresh server authority).
  Future<void> restoreAfterBackground() {
    if (_federatedSignInInProgress) return Future<void>.value();
    // A34 2026-11-08: after a long offline sleep the backoff sat at 60 s, and
    // the resume attempt usually runs before Wi-Fi is back, so the sign-in
    // screen stayed for a minute. Coming back starts the short delays again.
    _cancelOfflineRetry(resetBackoff: true);
    return restoreSession();
  }

  Future<bool> signInWithGoogle() async {
    final operation = _signInWithGoogleUseCase;
    if (operation == null) return false;
    // A startup/foreground restore holds the repository; wait for it instead
    // of failing the user's tap with auth_operation_in_progress (A34, 2026-11-06).
    final pendingRestore = _restoreSessionFuture;
    if (pendingRestore != null) {
      try {
        await pendingRestore;
      } catch (_) {
        /* Restore failure is already reflected in state. */
      }
    }
    // Credentials kept while offline: the button resumes them instead of a
    // fresh Google sign-in (which would refuse with an SDK user present and
    // wipe everything). Only a server refusal falls through to a new sign-in.
    if (_state.errorCode == offlineMessage) {
      try {
        await restoreSession();
      } catch (_) {
        /* Reflected in state. */
      }
      if (_state.isAuthenticated) return true;
      if (_state.errorCode == offlineMessage) return false;
    }
    final generation = ++_generation;
    _federatedSignInInProgress = true;
    _setState(_state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final result = await operation();
      if (generation != _generation) return false;
      _consumeAuthResult(result);
      return _state.isAuthenticated;
    } on AuthException catch (error) {
      if (kDebugMode) {
        debugPrint('recharge-auth: sign-in failed code=${error.code}');
      }
      if (generation == _generation) {
        _setState(
          error.code == cancelledCode
              ? const AuthState.guest()
              : const AuthState.guest().copyWith(
                  errorCode: error.code,
                  message: error.code,
                ),
        );
      }
      return false;
    } finally {
      _federatedSignInInProgress = false;
    }
  }

  Future<void> restoreSession() {
    final pendingRestore = _restoreSessionFuture;
    if (pendingRestore != null) {
      return pendingRestore;
    }

    final restoreCompleter = Completer<void>();
    final restoreFuture = restoreCompleter.future;
    _restoreSessionFuture = restoreFuture;

    unawaited(
      _restoreSession()
          .then<void>((_) {
            if (!restoreCompleter.isCompleted) {
              restoreCompleter.complete();
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!restoreCompleter.isCompleted) {
              restoreCompleter.completeError(error, stackTrace);
            }
          })
          .whenComplete(() {
            if (identical(_restoreSessionFuture, restoreFuture)) {
              _restoreSessionFuture = null;
            }
          }),
    );

    return restoreFuture;
  }

  Future<void> _restoreSession() async {
    final generation = _generation;
    _analyticsService.track(
      'auth_session_restore_started',
      params: <String, Object?>{
        'had_refresh_token': true,
        'source_screen': 'splash',
      },
    );
    final wasAuthenticated = _state.isAuthenticated;
    if (!wasAuthenticated) {
      _setState(_state.copyWith(status: AuthStatus.loading, clearError: true));
    }
    try {
      final result = await _restoreSessionUseCase();
      if (supportsGoogleSignIn && generation != _generation) return;
      _cancelOfflineRetry(resetBackoff: true);
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
      if (kDebugMode) {
        debugPrint('recharge-auth: restore failed code=${e.code}');
      }
      if (supportsGoogleSignIn && generation != _generation) return;
      if (supportsGoogleSignIn && e.code == offlineMessage) {
        // Keep the current UI authority while its snapshot is still valid;
        // otherwise show "no connection" (not "session expired") and retry.
        if (!wasAuthenticated) {
          _setState(
            const AuthState.guest().copyWith(
              errorCode: offlineMessage,
              message: offlineMessage,
            ),
          );
        }
        _scheduleOfflineRetry();
        return;
      }
      _cancelOfflineRetry(resetBackoff: true);
      _setState(
        const AuthState.guest().copyWith(
          errorCode: e.code,
          message: sessionExpiredMessage,
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
        params: <String, Object?>{'source_screen': 'splash'},
      );
    }
  }

  Future<void> signOut() async {
    if (supportsGoogleSignIn) {
      _generation++;
      _serverExpiry?.cancel();
      _cancelBackgroundRevalidation();
      _setState(const AuthState.guest());
    }
    _analyticsService.track(
      'auth_sign_out_started',
      params: <String, Object?>{'source_screen': 'profile'},
    );
    try {
      await _signOutUseCase();
      final restored = await _restoreSessionUseCase();
      if (restored == null) {
        _setState(const AuthState.guest());
      } else {
        _consumeAuthResult(restored);
      }
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
    _serverExpiry?.cancel();
    if (result.session.serverSessionHandle != null) {
      final remaining = result.session.expiresAtUtc.difference(
        DateTime.now().toUtc(),
      );
      if (remaining <= Duration.zero) {
        _setState(const AuthState.guest());
        return;
      }
      _serverExpiry = Timer(remaining, () {
        _generation++;
        clearPendingTarget();
        _silentRefresh?.cancel();
        _setState(
          const AuthState.guest().copyWith(
            errorCode: offlineMessage,
            message: offlineMessage,
          ),
        );
        // The snapshot ran out without a successful refresh (offline): the
        // Session itself lives on the server, so try again automatically.
        if (supportsGoogleSignIn) _scheduleOfflineRetry();
      });
      if (supportsGoogleSignIn) {
        final fifth = Duration(microseconds: remaining.inMicroseconds ~/ 5);
        final lead = fifth < silentRefreshLead ? fifth : silentRefreshLead;
        _silentRefresh?.cancel();
        _silentRefresh = Timer(remaining - lead, () {
          if (_federatedSignInInProgress) return;
          unawaited(restoreSession().catchError((Object _) {}));
        });
      }
    }
    _setState(AuthState(status: AuthStatus.authenticated, user: result.user));
  }

  void _scheduleOfflineRetry() {
    _offlineRetry?.cancel();
    final delays = offlineRetryDelays;
    final delay =
        delays[_offlineAttempt < delays.length
            ? _offlineAttempt
            : delays.length - 1];
    _offlineAttempt++;
    _offlineRetry = Timer(delay, () {
      if (_federatedSignInInProgress) return;
      unawaited(restoreSession().catchError((Object _) {}));
    });
  }

  void _cancelOfflineRetry({bool resetBackoff = false}) {
    _offlineRetry?.cancel();
    _offlineRetry = null;
    if (resetBackoff) _offlineAttempt = 0;
  }

  void _cancelBackgroundRevalidation() {
    _silentRefresh?.cancel();
    _silentRefresh = null;
    _cancelOfflineRetry(resetBackoff: true);
  }

  void _setState(AuthState state) {
    _state = state;
    if (state.status == AuthStatus.guest) _serverExpiry?.cancel();
    // L3: product analytics queues follow the signed-in account; sign-out or
    // another account deletes every other account's queue (amendment §6).
    _productAnalytics?.bindAccount(
      state.isAuthenticated ? state.user?.id : null,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _serverExpiry?.cancel();
    _cancelBackgroundRevalidation();
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }

  String _errorGroup(String code) {
    if (code.startsWith('AUTH_')) return 'auth';
    if (code.startsWith('VALIDATION_')) return 'validation';
    if (code.contains('NETWORK')) return 'network';
    return 'server';
  }
}
