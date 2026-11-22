import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'dev_auth_clear_journal.dart';
import 'dev_booking_cloud.dart';
import 'dev_content_media_port.dart';
import 'dev_notifications_bundle.dart';
import 'dev_push_registrar.dart';
import '../../core/config/cloud_environment.dart';

final class DevAuthBundle implements AuthSessionEvents {
  DevAuthBundle({
    required this.storage,
    required this.auth,
    required this.workspace,
    required this.sessions,
    required this.invalidated,
    this.contentMedia,
    this.notifications,
    this.booking,
  });
  @override
  final Stream<void> invalidated;
  final FlutterSecureStorage storage;
  final DevServerAuthRepository auth;
  @override
  Stream<void> get accessEnded => auth.accessEnded;
  final DevIdentityWorkspaceRepository workspace;
  final BookingIdentitySessionStore sessions;

  /// N3a.2: present only with `N3A2_DEV_PLACE_DRAFT=true`.
  final DevContentMediaPort? contentMedia;

  /// N3c: present only with `N3C_DEV_PUSH=true`.
  final DevNotificationsBundle? notifications;

  /// Debt plan round 1: the cloud Booking transport, present only with
  /// `N4C_DEV_BOOKING=true`.
  final BookingCallablePort? booking;
}

/// All values are public app configuration. No provider keys or SA credentials.
/// N4b: the `dev` flavor binds to the dev project, `stage` to staging; the
/// defines must belong to that project (number in the app and client ids).
Future<DevAuthBundle> createDevAuthBundleFromEnvironment() async {
  const enabled = bool.fromEnvironment('N2C_DEV_AUTH_CONFIGURED');
  const appId = String.fromEnvironment('N2C_FIREBASE_ANDROID_APP_ID');
  const apiKey = String.fromEnvironment('N2C_FIREBASE_ANDROID_API_KEY');
  const clientId = String.fromEnvironment('N2C_GOOGLE_SERVER_CLIENT_ID');
  final CloudEnvironment? cloud = CloudEnvironment.forFlavor(appFlavor);
  if (!enabled ||
      kReleaseMode ||
      cloud == null ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      !cloud.isAndroidAppId(appId) ||
      apiKey.isEmpty ||
      !cloud.isGoogleServerClientId(clientId)) {
    throw StateError('dev_auth_public_configuration_required');
  }
  final storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      sharedPreferencesName: '${cloud.storageScope}_secure',
      preferencesKeyPrefix: '${cloud.storageScope}_',
      resetOnError: false,
    ),
  );
  final options = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: cloud.projectNumber,
    projectId: cloud.projectId,
  );
  final app = await Firebase.initializeApp(
    name: cloud.firebaseAppName,
    options: options,
  );
  final BookingIdentityCacheEnvironment cacheEnvironment =
      cloud == CloudEnvironment.dev
      ? BookingIdentityCacheEnvironment.dev
      : BookingIdentityCacheEnvironment.staging;
  final sessions = SecureBookingIdentitySessionStore(
    storage,
    environment: cacheEnvironment,
  );
  final installations = SecureBookingInstallationIdProvider(
    storage,
    environment: cacheEnvironment,
  );
  final DevAuthClearJournal journal = await DevAuthClearJournal.open();
  final identity = DevAndroidGoogleIdentity(
    auth: FirebaseAuth.instanceFor(app: app),
    google: NativeDevGoogleAuthenticationDriver(clientId),
    sessions: sessions,
    onLocalSignOut: journal.record,
  );
  final endpoint = BookingBackendEndpoint.devIdentity(
    Uri.parse(cloud.functionsBase),
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
  late final DevServerAuthRepository auth;
  final callables = FunctionsBookingCallablePort(
    endpoint: endpoint,
    client: httpClient,
    tokens: identity,
    sessions: sessions,
    identitySessions: client,
    onAccessEnded: () => auth.endAccessFromTransport(),
  );
  DevNotificationsBundle? notifications;
  DevAuthSessionGateway gateway = NativeDevAuthSessionGateway(
    coordinator: coordinator,
    installations: installations,
    store: sessions,
  );
  if (n3cDevPushDefined) {
    // FCM on Android serves the default Firebase app only (same dev project).
    await Firebase.initializeApp(options: options);
    notifications = DevNotificationsBundle(
      port: DevNotificationsPort(callables),
      registrar: DevPushRegistrar(
        port: callables,
        messages: FirebaseDevPushMessages(FirebaseMessaging.instance),
      ),
    );
    gateway = PushAwareDevAuthSessionGateway(
      inner: gateway,
      registrar: notifications.registrar,
    );
  }
  auth = DevServerAuthRepository(gateway: gateway);
  return DevAuthBundle(
    storage: storage,
    auth: auth,
    workspace: createDevIdentityWorkspaceRepository(auth),
    sessions: sessions,
    contentMedia: n3a2DevPlaceDraftDefined
        ? DevContentMediaPort(callables)
        : null,
    notifications: notifications,
    booking: n4cDevBookingDefined ? callables : null,
    invalidated: FirebaseAuth.instanceFor(app: app)
        .authStateChanges()
        .where((User? user) {
          final bool mismatch = identity.hasMismatchedSdkUser;
          if (mismatch) {
            journal.record('invalidated sdkUserPresent=${user != null}');
          }
          return mismatch;
        })
        .map<void>((_) {}),
  );
}
