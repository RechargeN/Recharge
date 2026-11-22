import '../../domain/repositories/auth_session_events.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/product_analytics/product_analytics_recorder.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/auth_result_entity.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/network_status.dart';
import '../../domain/repositories/offline_account_store.dart';
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

  /// The server refused for now (rate limit): credentials are kept and the
  /// controller retries by itself, but only after the longest backoff step.
  static const String rateLimitedMessage = 'AUTH_TOO_MANY_ATTEMPTS';

  /// Another auth operation holds the repository; not a decision about the
  /// Session, so restore simply tries again.
  static const String busyCode = 'auth_operation_in_progress';

  /// Outcomes that keep the stored Session and the SDK user.
  static bool _keepsCredentials(String code) =>
      code == offlineMessage || code == rateLimitedMessage;

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
    OfflineAccountStore? offlineAccount,
    NetworkStatus? networkStatus,
  }) : _offlineAccount = offlineAccount,
       _networkStatus = networkStatus,
       _signInWithGoogleUseCase = signInWithGoogleUseCase,
       _signInUseCase = signInUseCase,
       _restoreSessionUseCase = restoreSessionUseCase,
       _signOutUseCase = signOutUseCase,
       _getCurrentUserUseCase = getCurrentUserUseCase,
       _analyticsService = analyticsService,
       _productAnalytics = productAnalytics {
    _sessionSubscription = sessionEvents?.invalidated.listen((_) {
      // The SDK lost its user. The server confirmed nothing, so no cache is
      // wiped (decision 2026-11-21 #5); the phone only signs out (#4).
      suspendServerAuthority();
      _forgetOfflineProfile();
      unawaited(_signOutUseCase().catchError((Object _) {}));
    });
    _accessEndedSubscription = sessionEvents?.accessEnded.listen((_) {
      // The server revoked the Session or blocked the account: nothing is left
      // to revoke, and the cached copies of server data go (decision #5).
      final ended = _lastConfirmedUser?.id;
      _serverUnreachable = false;
      suspendServerAuthority();
      _setState(
        const AuthState.guest().copyWith(
          errorCode: sessionExpiredMessage,
          message: sessionExpiredMessage,
        ),
      );
      unawaited(_wipeEndedAccount(ended).catchError((Object _) {}));
    });
    _networkSubscription = networkStatus?.changes.listen(
      _onNetwork,
      onError: (Object _) {},
    );
    unawaited(_readNetwork());
  }

  final OfflineAccountStore? _offlineAccount;

  final NetworkStatus? _networkStatus;
  StreamSubscription<bool>? _networkSubscription;

  /// The phone says there is no network.
  bool _networkLost = false;

  /// The last Session check did not reach the server.
  bool _serverUnreachable = false;

  /// Android reports no changes to a background app, and nothing is sent from
  /// there: the resume reads the status again.
  bool _inBackground = false;
  bool _disposed = false;

  Future<void> _readNetwork() async {
    final status = _networkStatus;
    if (status == null) return;
    final online = await status.isOnline();
    if (!_disposed) _onNetwork(online);
  }

  /// A34 2026-11-22: the network signal changes only what needs a connection,
  /// never the Session. The server answer stays the last word: a successful
  /// check clears a wrong "no network".
  void _onNetwork(bool online) {
    if (_networkLost != online) return; // Unchanged.
    _networkLost = !online;
    _publishConnection();
    if (_inBackground || !_state.isSignedIn || !supportsGoogleSignIn) return;
    if (!online) {
      if (!(_offlineRetry?.isActive ?? false)) _scheduleOfflineRetry();
    } else if (!(_rateLimitRetry?.isActive ?? false)) {
      _cancelOfflineRetry(resetBackoff: true);
      unawaited(restoreSession().catchError((Object _) {}));
    }
  }

  Future<void> _wipeEndedAccount(String? endedUserId) async {
    final store = _offlineAccount;
    if (store == null) return;
    // A cold start may hear the refusal before it knows the kept account.
    final userId = endedUserId ?? (await store.readOfflineProfile())?.id;
    if (userId == null) return store.clearOfflineProfile();
    await store.wipeAccountData(userId);
  }

  void _forgetOfflineProfile() {
    final store = _offlineAccount;
    if (store != null) {
      unawaited(store.clearOfflineProfile().catchError((Object _) {}));
    }
  }

  final SignInWithGoogleUseCase? _signInWithGoogleUseCase;
  bool get supportsGoogleSignIn => _signInWithGoogleUseCase != null;
  Timer? _serverExpiry;
  Timer? _silentRefresh;
  Timer? _offlineRetry;

  /// The server's rate-limit wait; unlike [_offlineRetry] it survives the
  /// background, since resuming inside it must send nothing.
  Timer? _rateLimitRetry;
  int _offlineAttempt = 0;
  StreamSubscription<void>? _sessionSubscription;
  StreamSubscription<void>? _accessEndedSubscription;
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
  final ValueNotifier<int> _authority = ValueNotifier<int>(0);

  /// For the router: every state change except a change of the connection
  /// alone. Its redirect reads access from the server, so re-running it when
  /// the network drops would eject the user from protected screens.
  Listenable get authorityChanges => _authority;

  /// The last user the server confirmed in this process; kept through an
  /// offline spell, dropped on sign-out, suspension or a server refusal.
  AuthUserEntity? _lastConfirmedUser;

  /// Round 1 (owner 2026-11-20, "человек в метро"): without network a signed-in
  /// user stays signed in on the saved screens instead of becoming a guest.
  AuthState _offlineOrGuest(String code) {
    final user = _lastConfirmedUser;
    if (user == null) {
      return const AuthState.guest().copyWith(errorCode: code, message: code);
    }
    return AuthState(
      status: AuthStatus.offline,
      user: user,
      errorCode: code,
      message: code,
    );
  }

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
    _lastConfirmedUser = null;
    _setState(const AuthState.guest());
  }

  /// App moved to the background (not a transient system overlay). Like
  /// Instagram-class apps the user stays signed in: UI authority still ends at
  /// the server snapshot expiry, every server call is still checked, and the
  /// return to the foreground revalidates. Pending retries wait for resume.
  void suspendForBackground() {
    if (_federatedSignInInProgress) return;
    _inBackground = true;
    _offlineRetry?.cancel();
  }

  /// Returning from the background revalidates with the server; skipped while
  /// a sign-in is still completing (its own result is fresh server authority).
  Future<void> restoreAfterBackground() {
    _inBackground = false;
    if (_federatedSignInInProgress) return Future<void>.value();
    unawaited(_readNetwork());
    // Inside the server's rate-limit wait nothing is sent: denied attempts
    // count in its window (N4b A34 staging 2026-11-15). The wait's own timer
    // tries again when it ends.
    if (_rateLimitRetry?.isActive ?? false) return Future<void>.value();
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
    if (_keepsCredentials(_state.errorCode ?? '')) {
      try {
        await restoreSession();
      } catch (_) {
        /* Reflected in state. */
      }
      if (_state.isAuthenticated) return true;
      if (_keepsCredentials(_state.errorCode ?? '')) return false;
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
    // Cold start without network: the kept profile lets the saved screens
    // open signed in (no role, no capabilities, no server authority).
    final store = _offlineAccount;
    if (_lastConfirmedUser == null && store != null) {
      AuthUserEntity? kept;
      try {
        kept = await store.readOfflineProfile();
      } catch (_) {
        /* No profile: the user starts as a guest, as before. */
      }
      // A sign-out during the read must not bring the user back.
      if (supportsGoogleSignIn && generation != _generation) return;
      _lastConfirmedUser = kept;
    }
    _analyticsService.track(
      'auth_session_restore_started',
      params: <String, Object?>{
        'had_refresh_token': true,
        'source_screen': 'splash',
      },
    );
    final wasAuthenticated = _state.isAuthenticated;
    // Offline stays offline while the check runs: no sign-in flash.
    if (!wasAuthenticated && !_state.isOffline) {
      _setState(_state.copyWith(status: AuthStatus.loading, clearError: true));
    }
    try {
      final result = await _restoreSessionUseCase();
      if (supportsGoogleSignIn && generation != _generation) return;
      _cancelOfflineRetry(resetBackoff: true);
      _rateLimitRetry?.cancel();
      _rateLimitRetry = null;
      if (result == null) {
        _serverUnreachable = false;
        _lastConfirmedUser = null;
        _forgetOfflineProfile();
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
      if (supportsGoogleSignIn && e.code == busyCode) {
        // N4b A34 2026-11-15: another auth operation was running; the Session
        // was not judged, so nothing is shown and restore tries again.
        _scheduleOfflineRetry();
        return;
      }
      if (supportsGoogleSignIn && _keepsCredentials(e.code)) {
        // Keep the current UI authority while its snapshot is still valid;
        // otherwise say what happened (not "session expired") and retry.
        _serverUnreachable = e.code == offlineMessage;
        // Authority lasts as long as the snapshot; the need for a connection
        // shows now.
        if (wasAuthenticated) {
          _publishConnection();
        } else {
          _setState(_offlineOrGuest(e.code));
        }
        if (e.code == rateLimitedMessage) {
          // Denied attempts count in the server's window too: never retry
          // before the server's own retryAfter, nor faster than the longest
          // backoff step. The wait survives the background (N4b A34 staging
          // 2026-11-15).
          _cancelOfflineRetry(resetBackoff: true);
          final longest = offlineRetryDelays.last;
          final retryAfter = e.retryAfter;
          final wait = retryAfter != null && retryAfter > longest
              ? retryAfter
              : longest;
          _rateLimitRetry?.cancel();
          _rateLimitRetry = Timer(wait, () {
            _rateLimitRetry = null;
            if (_federatedSignInInProgress) return;
            unawaited(restoreSession().catchError((Object _) {}));
          });
          return;
        }
        _scheduleOfflineRetry();
        return;
      }
      _cancelOfflineRetry(resetBackoff: true);
      // An explicit server refusal: the kept user is gone too.
      _serverUnreachable = false;
      _lastConfirmedUser = null;
      // Decision #4: the sign-in is gone, so a cold start without network must
      // not show it as signed in. The cache stays: nothing is confirmed.
      // Also for a stale snapshot: the app shows a guest from here, and a guest
      // must have no kept owner, because the Saved copy outlives a revocation.
      // The next confirmed answer saves the profile again.
      if (supportsGoogleSignIn) _forgetOfflineProfile();
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
    _lastConfirmedUser = null;
    _forgetOfflineProfile();
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
        _forgetOfflineProfile();
        _setState(const AuthState.guest());
        return;
      }
      _serverExpiry = Timer(remaining, () {
        // Not a user action: a refresh that is still running (A34 2026-11-19:
        // after sleep both timers fire together) must still be able to sign
        // the user back in, so the generation is left as it is. Sign-out and
        // suspension still invalidate it.
        clearPendingTarget();
        _silentRefresh?.cancel();
        _setState(_offlineOrGuest(offlineMessage));
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
    _networkLost = false;
    _serverUnreachable = false;
    _lastConfirmedUser = result.user;
    final store = _offlineAccount;
    if (store != null) {
      unawaited(
        store.saveOfflineProfile(result.user).catchError((Object _) {}),
      );
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
    _rateLimitRetry?.cancel();
    _rateLimitRetry = null;
    _cancelOfflineRetry(resetBackoff: true);
  }

  /// Only the need for a connection changed: widgets hear it, the router not.
  void _publishConnection() {
    final unavailable = _networkLost || _serverUnreachable;
    if (_state.networkUnavailable == unavailable) return;
    _state = _state.copyWith(networkUnavailable: unavailable);
    notifyListeners();
  }

  void _setState(AuthState next) {
    final state = next.copyWith(
      networkUnavailable: _networkLost || _serverUnreachable,
    );
    _state = state;
    if (state.status == AuthStatus.guest) _serverExpiry?.cancel();
    // L3: product analytics queues follow the signed-in account; sign-out or
    // another account deletes every other account's queue (amendment §6).
    // Offline keeps the account: it is not a sign-out.
    _productAnalytics?.bindAccount(state.isSignedIn ? state.user?.id : null);
    notifyListeners();
    // After the listeners: the router's actor is synchronized before it redirects.
    _authority.value++;
  }

  @override
  void dispose() {
    _serverExpiry?.cancel();
    _cancelBackgroundRevalidation();
    _disposed = true;
    unawaited(_networkSubscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
    unawaited(_accessEndedSubscription?.cancel());
    _authority.dispose();
    super.dispose();
  }

  String _errorGroup(String code) {
    if (code.startsWith('AUTH_')) return 'auth';
    if (code.startsWith('VALIDATION_')) return 'validation';
    if (code.contains('NETWORK')) return 'network';
    return 'server';
  }
}
