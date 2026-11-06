import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'booking_functions_transport.dart';
import 'booking_identity_failure.dart';

/// Provider credentials only; never supplies Recharge roles or Session authority.
abstract interface class DevGoogleAuthenticationDriver {
  Future<String> authenticateIdToken();
  Future<void> signOut();
}

final class NativeDevGoogleAuthenticationDriver
    implements DevGoogleAuthenticationDriver {
  NativeDevGoogleAuthenticationDriver(this.serverClientId) {
    if (!RegExp(
      r'^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$',
    ).hasMatch(serverClientId)) {
      throw const FormatException('dev_google_client_id_invalid');
    }
  }

  final String serverClientId;
  static String? _initializedClientId;
  static Future<void>? _initialization;

  Future<void> _initialize() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw StateError('dev_android_only');
    }
    if (_initializedClientId != null &&
        _initializedClientId != serverClientId) {
      throw StateError('dev_google_client_binding_conflict');
    }
    _initializedClientId = serverClientId;
    // The native SDK singleton must be initialized exactly once per process.
    return _initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
  }

  @override
  Future<String> authenticateIdToken() async {
    await _initialize();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('dev_google_authentication_unavailable');
    }
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.trim().isEmpty) {
      throw StateError('dev_google_id_token_missing');
    }
    return token;
  }

  @override
  Future<void> signOut() async {
    if (_initialization == null) return;
    await _initialize();
    await GoogleSignIn.instance.signOut();
  }
}

void _assertDevAndroidApp(FirebaseApp app) {
  if (app.name != 'recharge-dev-android' ||
      app.options.projectId != 'recharge-dev-n2a01' ||
      app.options.messagingSenderId != '420479958348' ||
      !RegExp(
        r'^1:420479958348:android:[a-f0-9]+$',
      ).hasMatch(app.options.appId)) {
    throw StateError('dev_android_firebase_binding_invalid');
  }
}

/// Explicitly supplied SDK instance; no default app resolution or automatic sign-in.
/// This remains disconnected from the default Local/Emulator composition.
final class DevAndroidGoogleIdentity implements BookingFirebaseIdTokenProvider {
  DevAndroidGoogleIdentity({
    required FirebaseAuth auth,
    required DevGoogleAuthenticationDriver google,
    required BookingIdentitySessionStore sessions,
  }) : _auth = auth,
       _google = google,
       _sessions = sessions {
    _assertDevAndroidApp(auth.app);
  }

  final FirebaseAuth _auth;
  final DevGoogleAuthenticationDriver _google;
  final BookingIdentitySessionStore _sessions;
  bool get hasMismatchedSdkUser =>
      _authenticatedUid != null && _auth.currentUser?.uid != _authenticatedUid;
  bool _busy = false;
  bool _tokenAccessEnabled = false;
  String? _authenticatedUid;

  /// Returns provider uid only. Recharge Session must be established by the server.
  Future<String> signInWithGoogle() async {
    _assertDevAndroidApp(_auth.app);
    if (_busy) throw StateError('dev_identity_operation_in_progress');
    if (_auth.currentUser != null) {
      throw StateError('dev_identity_sign_out_required');
    }
    _busy = true;
    try {
      await _sessions.clear();
      final token = await _google.authenticateIdToken();
      if (token.trim().isEmpty) throw StateError('dev_google_id_token_missing');
      _assertDevAndroidApp(_auth.app);
      final result = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
      final user = result.user;
      if (user == null ||
          user.uid.isEmpty ||
          _auth.currentUser?.uid != user.uid) {
        await _auth.signOut();
        throw StateError('dev_identity_user_missing');
      }
      _authenticatedUid = user.uid;
      _tokenAccessEnabled = true;
      return user.uid;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async {
    _assertDevAndroidApp(_auth.app);
    if (_busy || !_tokenAccessEnabled) return null;
    final user = _auth.currentUser;
    if (user == null || user.uid != _authenticatedUid) {
      _tokenAccessEnabled = false;
      _authenticatedUid = null;
      await _sessions.clear();
      return null;
    }
    final token = await user.getIdToken(forceRefresh);
    _assertDevAndroidApp(_auth.app);
    if (_busy ||
        !_tokenAccessEnabled ||
        _auth.currentUser?.uid != _authenticatedUid) {
      return null;
    }
    return token;
  }

  /// Local logout only; global Firebase/Recharge revocation is a server operation.
  Future<void> signOutLocal() async {
    _assertDevAndroidApp(_auth.app);
    if (_busy) throw StateError('dev_identity_operation_in_progress');
    _busy = true;
    _tokenAccessEnabled = false;
    _authenticatedUid = null;
    try {
      // Attempt all cleanup paths, even when one SDK/storage operation fails.
      await Future.wait<void>([
        Future<void>.sync(_sessions.clear),
        Future<void>.sync(_auth.signOut),
        Future<void>.sync(_google.signOut),
      ]);
    } finally {
      _busy = false;
    }
  }
}

enum DevAndroidAttestationMode { playIntegrity, debug }

final class DevAndroidAppCheckTokens implements BookingAppCheckTokenProvider {
  DevAndroidAppCheckTokens(
    this._appCheck, {
    this.mode = DevAndroidAttestationMode.playIntegrity,
  }) {
    _assertDevAndroidApp(_appCheck.app);
  }

  final DevAndroidAttestationMode mode;
  final FirebaseAppCheck _appCheck;
  Future<void>? _activation;

  @override
  Future<String> currentToken({bool forceRefresh = false}) async {
    _assertDevAndroidApp(_appCheck.app);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw StateError('dev_android_only');
    }
    if (mode == DevAndroidAttestationMode.debug && kReleaseMode) {
      throw StateError('debug_attestation_release_forbidden');
    }
    // Owner registers SDK-generated debug token directly in Firebase console.
    // Never capture SDK debug-token logs in automated evidence.
    await (_activation ??= _appCheck.activate(
      providerAndroid: mode == DevAndroidAttestationMode.debug
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    ));
    _assertDevAndroidApp(_appCheck.app);
    final token = await _appCheck.getToken(forceRefresh);
    if (token == null || token.trim().isEmpty) {
      throw StateError('dev_app_check_token_missing');
    }
    return token;
  }
}

/// Provider authentication is not a signed-in Recharge account until Session succeeds.
final class DevAndroidIdentitySessionCoordinator {
  DevAndroidIdentitySessionCoordinator({
    required this.identity,
    required this.sessions,
  }) {
    final store = identity._sessions;
    if (!sessions.isDevGoogleFor(store, identity) ||
        (store is SecureBookingIdentitySessionStore &&
            store.environment != BookingIdentityCacheEnvironment.dev)) {
      throw StateError('dev_identity_session_composition_invalid');
    }
  }
  final DevAndroidGoogleIdentity identity;
  final FunctionsIdentitySessionClient sessions;
  bool _busy = false;

  Future<BookingIdentitySessionContext?> restoreSession({
    required String requestId,
    Future<void> Function(Map<String, Object?> data)? onAuthContext,
  }) async {
    if (_busy) throw StateError('dev_identity_operation_in_progress');
    _busy = true;
    try {
      _assertDevAndroidApp(identity._auth.app);
      final stored = await identity._sessions.read();
      if (stored == null) return null;
      final user = await identity._auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
      );
      _assertDevAndroidApp(identity._auth.app);
      if (user == null || identity._auth.currentUser?.uid != user.uid) {
        await identity.signOutLocal();
        return null;
      }
      // Only transport credentials are enabled here; server verifies the old handle/uid.
      identity._authenticatedUid = user.uid;
      identity._tokenAccessEnabled = true;
      return await sessions.refresh(
        requestId: requestId,
        requireExistingSession: true,
        forceRefreshToken: true,
        onAuthContext: onAuthContext,
      );
    } catch (error, stack) {
      if (!isTransientIdentityFailure(error)) {
        try {
          await identity.signOutLocal();
        } catch (_) {
          /* Access is closed before SDK cleanup. */
        }
      }
      Error.throwWithStackTrace(error, stack);
    } finally {
      _busy = false;
    }
  }

  Future<BookingIdentitySessionContext> signInWithGoogle({
    required String requestId,
    Future<void> Function(Map<String, Object?> data)? onAuthContext,
  }) async {
    if (_busy) throw StateError('dev_identity_operation_in_progress');
    _busy = true;
    try {
      await identity.signInWithGoogle();
      try {
        return await sessions.establish(
          requestId: requestId,
          onAuthContext: onAuthContext,
        );
      } catch (error, stack) {
        try {
          await identity.signOutLocal();
        } catch (_) {
          /* Access already closed. */
        }
        Error.throwWithStackTrace(error, stack);
      }
    } finally {
      _busy = false;
    }
  }
}

/// Expected dev attestation failures are observations; binding errors still fail closed.
final class ObservedDevAppCheckTokens implements BookingAppCheckTokenProvider {
  const ObservedDevAppCheckTokens(this.delegate);
  final DevAndroidAppCheckTokens delegate;
  @override
  Future<String> currentToken({bool forceRefresh = false}) async {
    try {
      return await delegate.currentToken(forceRefresh: forceRefresh);
    } on FirebaseException {
      return '';
    } on StateError catch (error) {
      if (error.message == 'dev_app_check_token_missing') return '';
      rethrow;
    }
  }
}
