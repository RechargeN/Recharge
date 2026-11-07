import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../features/auth/data/repositories/dev_server_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_session_events.dart';
import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_dev_android_identity.dart';
import '../../features/booking/data/booking_functions_transport.dart';
import '../../features/identity/data/repositories/dev_identity_workspace_repository.dart';
import 'native_dev_auth_session_gateway.dart';
import 'dev_auth_workspace_composition.dart';
import 'dev_content_media_port.dart';

final class DevAuthBundle implements AuthSessionEvents {
  DevAuthBundle({
    required this.storage,
    required this.auth,
    required this.workspace,
    required this.sessions,
    required this.invalidated,
    this.contentMedia,
  });
  @override
  final Stream<void> invalidated;
  final FlutterSecureStorage storage;
  final DevServerAuthRepository auth;
  final DevIdentityWorkspaceRepository workspace;
  final BookingIdentitySessionStore sessions;

  /// N3a.2: present only with `N3A2_DEV_PLACE_DRAFT=true`.
  final DevContentMediaPort? contentMedia;
}

/// All values are public app configuration. No provider keys or SA credentials.
Future<DevAuthBundle> createDevAuthBundleFromEnvironment() async {
  const enabled = bool.fromEnvironment('N2C_DEV_AUTH_CONFIGURED');
  const appId = String.fromEnvironment('N2C_FIREBASE_ANDROID_APP_ID');
  const apiKey = String.fromEnvironment('N2C_FIREBASE_ANDROID_API_KEY');
  const clientId = String.fromEnvironment('N2C_GOOGLE_SERVER_CLIENT_ID');
  if (!enabled ||
      kReleaseMode ||
      appFlavor != 'dev' ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      !RegExp(r'^1:420479958348:android:[a-f0-9]+$').hasMatch(appId) ||
      apiKey.isEmpty ||
      !RegExp(
        r'^420479958348-[a-z0-9]+\.apps\.googleusercontent\.com$',
      ).hasMatch(clientId)) {
    throw StateError('dev_auth_public_configuration_required');
  }
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      sharedPreferencesName: 'recharge_dev_n2a01_secure',
      preferencesKeyPrefix: 'recharge_dev_n2a01_',
      resetOnError: false,
    ),
  );
  final app = await Firebase.initializeApp(
    name: 'recharge-dev-android',
    options: const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: '420479958348',
      projectId: 'recharge-dev-n2a01',
    ),
  );
  final sessions = SecureBookingIdentitySessionStore(
    storage,
    environment: BookingIdentityCacheEnvironment.dev,
  );
  final installations = SecureBookingInstallationIdProvider(
    storage,
    environment: BookingIdentityCacheEnvironment.dev,
  );
  final identity = DevAndroidGoogleIdentity(
    auth: FirebaseAuth.instanceFor(app: app),
    google: NativeDevGoogleAuthenticationDriver(clientId),
    sessions: sessions,
  );
  final endpoint = BookingBackendEndpoint.devIdentity(
    Uri.parse('https://europe-west1-recharge-dev-n2a01.cloudfunctions.net'),
  );
  final httpClient = http.Client();
  final client = FunctionsIdentitySessionClient(
    endpoint: endpoint,
    client: httpClient,
    tokens: identity,
    installations: installations,
    sessions: sessions,
    appCheck: ObservedDevAppCheckTokens(
      DevAndroidAppCheckTokens(
        FirebaseAppCheck.instanceFor(app: app),
        mode: DevAndroidAttestationMode.debug,
      ),
    ),
    observeAppCheck: true,
    identityProvider: 'google',
  );
  final coordinator = DevAndroidIdentitySessionCoordinator(
    identity: identity,
    sessions: client,
  );
  final auth = DevServerAuthRepository(
    gateway: NativeDevAuthSessionGateway(
      coordinator: coordinator,
      installations: installations,
      store: sessions,
    ),
  );
  return DevAuthBundle(
    storage: storage,
    auth: auth,
    workspace: createDevIdentityWorkspaceRepository(auth),
    sessions: sessions,
    contentMedia: n3a2DevPlaceDraftDefined
        ? DevContentMediaPort(
            FunctionsBookingCallablePort(
              endpoint: endpoint,
              client: httpClient,
              tokens: identity,
              sessions: sessions,
              identitySessions: client,
            ),
          )
        : null,
    invalidated: FirebaseAuth.instanceFor(app: app)
        .authStateChanges()
        .where((_) => identity.hasMismatchedSdkUser)
        .map<void>((_) {}),
  );
}
