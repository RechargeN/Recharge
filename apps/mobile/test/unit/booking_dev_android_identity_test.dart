import 'package:recharge/features/auth/data/repositories/dev_server_auth_repository.dart';
import 'package:recharge/app/di/native_dev_auth_session_gateway.dart';
import '../fixtures/auth/server_auth_packet.dart' as auth_fixture;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/data/booking_dev_android_identity.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';

class _App extends Fake implements FirebaseApp {
  _App({
    this.project = 'recharge-dev-n2a01',
    this.appName = 'recharge-dev-android',
  });
  final String project;
  final String appName;
  @override
  String get name => appName;
  @override
  FirebaseOptions get options => FirebaseOptions(
    apiKey: 'nonfunctional-test-config',
    appId: '1:420479958348:android:abcdef',
    messagingSenderId: '420479958348',
    projectId: project,
  );
}

class _User extends Fake implements User {
  _User([this.identity = 'provider-test-uid']);
  final String identity;
  @override
  String get uid => identity;
  bool? refreshed;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    refreshed = forceRefresh;
    return 'synthetic-firebase-id-token';
  }
}

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);
  @override
  final User? user;
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  FirebaseApp app = _App();
  @override
  User? currentUser;
  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(currentUser);
  bool failLogout = false;
  int signIns = 0;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    expect(credential.providerId, 'google.com');
    signIns++;
    currentUser = _User();
    return _Credential(currentUser);
  }

  @override
  Future<void> signOut() {
    if (failLogout) throw StateError('logout-failed');
    currentUser = null;
    return Future<void>.value();
  }
}

class _Google implements DevGoogleAuthenticationDriver {
  int signOuts = 0;
  Future<String> Function() authenticate = () async =>
      'synthetic-google-id-token';
  @override
  Future<String> authenticateIdToken() => authenticate();
  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class _AppCheck extends Fake implements FirebaseAppCheck {
  @override
  FirebaseApp app = _App();
  int activations = 0;
  String? token = 'synthetic-app-check-token';
  Object? failure;
  Type expectedProvider = AndroidPlayIntegrityProvider;
  Object? lastProvider;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #activate) {
      expect(
        invocation.namedArguments[#providerAndroid].runtimeType,
        expectedProvider,
      );
      activations++;
      lastProvider = invocation.namedArguments[#providerAndroid];
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }

  @override
  Future<String?> getToken([bool? forceRefresh]) async {
    if (failure != null) throw failure!;
    return token;
  }
}

class _Installations implements BookingInstallationIdProvider {
  @override
  Future<String> current() async => 'test-installation';
}

void main() {
  late _Auth auth;
  late _Google google;
  late InMemoryBookingIdentitySessionStore sessions;
  late DevAndroidGoogleIdentity identity;
  setUp(() {
    auth = _Auth();
    google = _Google();
    sessions = InMemoryBookingIdentitySessionStore();
    identity = DevAndroidGoogleIdentity(
      auth: auth,
      google: google,
      sessions: sessions,
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'native gateway returns only validated server Auth projection',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final data = auth_fixture.packet();
      final current = DateTime.now().toUtc();
      final expiry = current.add(const Duration(minutes: 30)).toIso8601String();
      (data['sessionContext'] as Map)['installationId'] = 'test-installation';
      (data['sessionContext'] as Map)['expiresAtUtc'] = expiry;
      final snapshot = (data['authContext'] as Map)['accessSnapshot'] as Map;
      snapshot['expiresAtUtc'] = expiry;
      snapshot['evaluatedAtUtc'] = current
          .subtract(const Duration(seconds: 1))
          .toIso8601String();
      final client = FunctionsIdentitySessionClient(
        endpoint: BookingBackendEndpoint.devIdentity(
          Uri.parse(
            'https://europe-west1-recharge-dev-n2a01.cloudfunctions.net',
          ),
        ),
        client: MockClient((request) async {
          final command = (jsonDecode(request.body) as Map)['data'] as Map;
          return http.Response(
            jsonEncode({
              'result': {
                'schemaVersion': 1,
                'commandType': command['commandType'],
                'requestId': command['requestId'],
                'kind': 'succeeded',
                'data': data,
              },
            }),
            200,
          );
        }),
        tokens: identity,
        installations: _Installations(),
        sessions: sessions,
        appCheck: DevAndroidAppCheckTokens(_AppCheck()),
        identityProvider: 'google',
      );
      final coordinator = DevAndroidIdentitySessionCoordinator(
        identity: identity,
        sessions: client,
      );
      final gateway = NativeDevAuthSessionGateway(
        coordinator: coordinator,
        installations: _Installations(),
        store: sessions,
        revokeCurrentSession: () async {},
        now: () => current,
      );
      final repository = DevServerAuthRepository(
        gateway: gateway,
        now: () => current,
      );
      final result = await repository.signInWithGoogle();
      expect(result.user.id, '018FQ2Z8Q9N4M7K2T6V3W1X5YA');
      expect(result.user.role, 'user');
      expect(result.user.capabilities, ['booking.self_service']);
      expect(result.session.accessToken, isNull);
    },
  );

  for (final accepted in [true, false]) {
    test(
      'cold SDK restore rotates old server handle; accepted=$accepted',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        auth.currentUser =
            _User(); // Persisted SDK user, no new Google sign-in.
        await sessions.saveServerIssued(
          BookingIdentitySessionContext(
            sessionId: 'old-session',
            sessionHandle: 'A' * 43,
            installationId: 'test-installation',
          ),
        );
        var calls = 0;
        final client = FunctionsIdentitySessionClient(
          endpoint: BookingBackendEndpoint.devIdentity(
            Uri.parse(
              'https://europe-west1-recharge-dev-n2a01.cloudfunctions.net',
            ),
          ),
          client: MockClient((request) async {
            calls++;
            expect(request.url.path, '/refreshIdentitySessionV1');
            return http.Response(
              jsonEncode({
                'result': {
                  'schemaVersion': 1,
                  'commandType': 'refreshIdentitySession',
                  'requestId': 'restore',
                  'kind': accepted ? 'succeeded' : 'rejected',
                  if (!accepted) 'error': {'code': 'session_revoked'},
                  if (accepted)
                    'data': {
                      'sessionContext': {
                        'userId': 'server-user',
                        'sessionId': 'new-session',
                        'sessionHandle': 'B' * 43,
                        'installationId': 'test-installation',
                        'expiresAtUtc': DateTime.now()
                            .toUtc()
                            .add(const Duration(minutes: 30))
                            .toIso8601String(),
                      },
                    },
                },
              }),
              200,
            );
          }),
          tokens: identity,
          installations: _Installations(),
          sessions: sessions,
          appCheck: DevAndroidAppCheckTokens(_AppCheck()),
          identityProvider: 'google',
        );
        final coordinator = DevAndroidIdentitySessionCoordinator(
          identity: identity,
          sessions: client,
        );
        if (accepted) {
          expect(
            (await coordinator.restoreSession(
              requestId: 'restore',
            ))!.sessionHandle,
            'B' * 43,
          );
          expect(await identity.currentIdToken(), isNotNull);
        } else {
          await expectLater(
            coordinator.restoreSession(requestId: 'restore'),
            throwsA(isA<BookingCallableFailure>()),
          );
          expect(await identity.currentIdToken(), isNull);
          expect(await sessions.read(), isNull);
        }
        expect(auth.signIns, 0);
        expect(calls, 1);
      },
    );
  }

  test('offline cold restore keeps the SDK user and stored Session', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    auth.currentUser = _User();
    await sessions.saveServerIssued(
      BookingIdentitySessionContext(
        sessionId: 'old-session',
        sessionHandle: 'A' * 43,
        installationId: 'test-installation',
      ),
    );
    final client = FunctionsIdentitySessionClient(
      endpoint: BookingBackendEndpoint.devIdentity(
        Uri.parse('https://europe-west1-recharge-dev-n2a01.cloudfunctions.net'),
      ),
      client: MockClient((_) async => throw http.ClientException('offline')),
      tokens: identity,
      installations: _Installations(),
      sessions: sessions,
      appCheck: DevAndroidAppCheckTokens(_AppCheck()),
      identityProvider: 'google',
    );
    final coordinator = DevAndroidIdentitySessionCoordinator(
      identity: identity,
      sessions: client,
    );
    await expectLater(
      coordinator.restoreSession(requestId: 'restore'),
      throwsA(isA<BookingCallableFailure>()),
    );
    expect(auth.currentUser, isNotNull);
    expect(await sessions.read(), isNotNull);
  });

  test('coordinator rejects a different Firebase token provider', () {
    final client = FunctionsIdentitySessionClient(
      endpoint: BookingBackendEndpoint.devIdentity(
        Uri.parse('https://europe-west1-recharge-dev-n2a01.cloudfunctions.net'),
      ),
      client: MockClient((_) async => http.Response('{}', 500)),
      tokens: const DisabledBookingFirebaseIdTokenProvider(),
      installations: _Installations(),
      sessions: sessions,
      appCheck: DevAndroidAppCheckTokens(_AppCheck()),
      identityProvider: 'google',
    );
    expect(
      () => DevAndroidIdentitySessionCoordinator(
        identity: identity,
        sessions: client,
      ),
      throwsStateError,
    );
    expect(auth.signIns, 0);
  });

  for (final succeeds in [true, false]) {
    test(
      'SDK to server Session coordinator succeeds=$succeeds without local grants',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final client = FunctionsIdentitySessionClient(
          endpoint: BookingBackendEndpoint.devIdentity(
            Uri.parse(
              'https://europe-west1-recharge-dev-n2a01.cloudfunctions.net',
            ),
          ),
          client: MockClient((request) async {
            expect(auth.currentUser, isNotNull);
            expect(
              request.headers['X-Firebase-AppCheck'],
              'synthetic-app-check-token',
            );
            return http.Response(
              jsonEncode({
                'result': {
                  'schemaVersion': 1,
                  'commandType': 'establishIdentitySession',
                  'requestId': 'attempt',
                  'kind': succeeds ? 'succeeded' : 'rejected',
                  if (!succeeds)
                    'error': {'code': 'provider_assertion_invalid'},
                  if (succeeds)
                    'data': {
                      'sessionContext': {
                        'userId': 'server-user',
                        'sessionId': 'server-session',
                        'sessionHandle': 'A' * 43,
                        'installationId': 'test-installation',
                        'expiresAtUtc': DateTime.now()
                            .toUtc()
                            .add(const Duration(minutes: 30))
                            .toIso8601String(),
                      },
                    },
                },
              }),
              200,
            );
          }),
          tokens: identity,
          installations: _Installations(),
          sessions: sessions,
          appCheck: DevAndroidAppCheckTokens(_AppCheck()),
          identityProvider: 'google',
        );
        final coordinator = DevAndroidIdentitySessionCoordinator(
          identity: identity,
          sessions: client,
        );
        if (succeeds) {
          expect(
            (await coordinator.signInWithGoogle(
              requestId: 'attempt',
            )).sessionId,
            'server-session',
          );
          expect(
            (await sessions.read())!.toJson().keys,
            unorderedEquals(['sessionId', 'sessionHandle', 'installationId']),
          );
        } else {
          await expectLater(
            coordinator.signInWithGoogle(requestId: 'attempt'),
            throwsA(isA<BookingCallableFailure>()),
          );
          expect(auth.currentUser, isNull);
          expect(await identity.currentIdToken(), isNull);
          expect(await sessions.read(), isNull);
        }
      },
    );
  }

  test('rejects foreign/default app binding without SDK sign-in', () {
    for (final app in [
      _App(project: 'other-project'),
      _App(appName: '[DEFAULT]'),
    ]) {
      auth.app = app;
      expect(
        () => DevAndroidGoogleIdentity(
          auth: auth,
          google: google,
          sessions: sessions,
        ),
        throwsStateError,
      );
    }
    expect(auth.signIns, 0);
  });

  test(
    'Google sign-in clears stale Session and only supplies Firebase token',
    () async {
      await sessions.saveServerIssued(
        BookingIdentitySessionContext(
          sessionId: 'old-session',
          sessionHandle: 'A' * 43,
          installationId: 'test-installation',
        ),
      );
      expect(await identity.currentIdToken(), isNull);
      expect(await identity.signInWithGoogle(), 'provider-test-uid');
      expect(await sessions.read(), isNull);
      expect(
        await identity.currentIdToken(forceRefresh: true),
        'synthetic-firebase-id-token',
      );
      expect((auth.currentUser as _User).refreshed, isTrue);
      await expectLater(identity.signInWithGoogle(), throwsStateError);
      expect(auth.signIns, 1);
    },
  );

  test(
    'cancellation/empty token do not authenticate or mint Session',
    () async {
      google.authenticate = () => Future.error(StateError('cancelled'));
      await expectLater(identity.signInWithGoogle(), throwsStateError);
      google.authenticate = () async => ' ';
      await expectLater(identity.signInWithGoogle(), throwsStateError);
      expect(auth.signIns, 0);
      expect(await identity.currentIdToken(), isNull);
      expect(await sessions.read(), isNull);
    },
  );

  test(
    'concurrent login/logout are rejected while token access stays closed',
    () async {
      final pending = Completer<String>();
      google.authenticate = () => pending.future;
      final login = identity.signInWithGoogle();
      await expectLater(identity.signInWithGoogle(), throwsStateError);
      await expectLater(identity.signOutLocal(), throwsStateError);
      expect(await identity.currentIdToken(), isNull);
      pending.complete('synthetic-google-id-token');
      await login;
    },
  );

  test(
    'failed Firebase logout still clears Session and Google; tokens stay closed',
    () async {
      await identity.signInWithGoogle();
      auth.failLogout = true;
      await expectLater(identity.signOutLocal(), throwsStateError);
      expect(google.signOuts, 1);
      expect(await sessions.read(), isNull);
      expect(await identity.currentIdToken(), isNull);
    },
  );

  test(
    'binding is rechecked before token access after mutable SDK app changes',
    () async {
      await identity.signInWithGoogle();
      auth.app = _App(project: 'other-project');
      await expectLater(identity.currentIdToken(), throwsStateError);
    },
  );

  test(
    'App Check uses Play Integrity once and never substitutes missing tokens',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final sdk = _AppCheck();
      final tokens = DevAndroidAppCheckTokens(sdk);
      expect(await tokens.currentToken(), 'synthetic-app-check-token');
      expect(
        await tokens.currentToken(forceRefresh: true),
        'synthetic-app-check-token',
      );
      expect(sdk.activations, 1);
      sdk.token = null;
      await expectLater(tokens.currentToken(), throwsStateError);
      sdk.app = _App(project: 'other-project');
      await expectLater(tokens.currentToken(), throwsStateError);
    },
  );

  test(
    'an external account switch cannot inherit token access or Session',
    () async {
      await identity.signInWithGoogle();
      auth.currentUser = _User('another-provider-uid');
      expect(await identity.currentIdToken(), isNull);
      expect(await sessions.read(), isNull);
    },
  );

  test('App Check refuses other platforms before activation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final sdk = _AppCheck();
    await expectLater(
      DevAndroidAppCheckTokens(sdk).currentToken(),
      throwsStateError,
    );
    expect(sdk.activations, 0);
  });

  test(
    'dev debug attestation uses only the SDK debug provider and never a token literal',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final sdk = _AppCheck()..expectedProvider = AndroidDebugProvider;
      final tokens = DevAndroidAppCheckTokens(
        sdk,
        mode: DevAndroidAttestationMode.debug,
      );
      expect(await tokens.currentToken(), 'synthetic-app-check-token');
      expect(sdk.activations, 1);
      expect((sdk.lastProvider! as AndroidDebugProvider).debugToken, isNull);
    },
  );

  test(
    'observed App Check maps only attestation failures to an empty observation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final sdk = _AppCheck()..expectedProvider = AndroidDebugProvider;
      final observed = ObservedDevAppCheckTokens(
        DevAndroidAppCheckTokens(sdk, mode: DevAndroidAttestationMode.debug),
      );
      expect(await observed.currentToken(), 'synthetic-app-check-token');
      sdk.token = null;
      expect(await observed.currentToken(), isEmpty);
      sdk
        ..token = 'synthetic-app-check-token'
        ..failure = FirebaseException(
          plugin: 'firebase_app_check',
          code: 'unknown',
        );
      expect(await observed.currentToken(), isEmpty);
      sdk
        ..failure = null
        ..app = _App(project: 'other-project');
      await expectLater(observed.currentToken(), throwsStateError);
      sdk.app = _App();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await expectLater(observed.currentToken(), throwsStateError);
    },
  );
}
