import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/repositories/auth_session_events.dart';
import 'package:recharge/features/auth/domain/repositories/offline_account_store.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';

// Owner decisions 2026-11-21 #4–5: a confirmed end of access wipes the cache;
// every other end of sign-in forgets the offline profile only; no network,
// timeout or server error changes nothing.

const _user = AuthUserEntity(
  id: 'server-user',
  email: '',
  role: 'user',
  capabilities: <String>[],
  profileStatus: 'active',
);

class _Events implements AuthSessionEvents {
  final invalidations = StreamController<void>.broadcast(sync: true);
  final ends = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get invalidated => invalidations.stream;

  @override
  Stream<void> get accessEnded => ends.stream;
}

class _Store implements OfflineAccountStore {
  AuthUserEntity? profile;
  Completer<AuthUserEntity?>? slowRead;
  final List<String> wiped = <String>[];

  @override
  Future<void> saveOfflineProfile(AuthUserEntity user) async => profile = user;

  @override
  Future<AuthUserEntity?> readOfflineProfile() =>
      slowRead?.future ?? Future<AuthUserEntity?>.value(profile);

  @override
  Future<void> clearOfflineProfile() async => profile = null;

  @override
  Future<void> wipeAccountData(String userId) async {
    wiped.add(userId);
    profile = null;
  }
}

class _Repository implements FederatedAuthRepository {
  _Repository(this.events);

  final _Events events;
  String? failure;

  /// The server ended access: the signal comes before the thrown refusal.
  bool ended = false;
  int signOuts = 0;
  bool signedOut = false;

  @override
  Future<AuthResultEntity?> restoreSession() async {
    if (ended) {
      events.ends.add(null);
      throw const AuthException(code: 'ACCESS_ENDED', message: '');
    }
    final code = failure;
    if (code != null) throw AuthException(code: code, message: '');
    if (signedOut) return null;
    return AuthResultEntity(
      session: AuthSessionEntity.serverIssued(
        sessionId: 'server',
        serverSessionHandle: 'A' * 43,
        installationId: 'install',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      user: _user,
    );
  }

  @override
  Future<AuthResultEntity> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<AuthUserEntity?> getCurrentUser() async => null;

  @override
  Future<void> signOut() async {
    signOuts++;
    signedOut = true;
  }

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) => throw UnimplementedError();
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

void main() {
  late _Events events;
  late _Store store;
  late _Repository repository;
  late AuthController controller;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    events = _Events();
    store = _Store();
    repository = _Repository(events);
    controller = AuthController(
      signInUseCase: SignInUseCase(repository),
      restoreSessionUseCase: RestoreSessionUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      analyticsService: _Analytics(),
      signInWithGoogleUseCase: SignInWithGoogleUseCase(repository),
      sessionEvents: events,
      offlineAccount: store,
    );
  });

  tearDown(() async {
    controller.dispose();
    await events.invalidations.close();
    await events.ends.close();
  });

  Future<void> signedIn() async {
    await controller.restoreSession();
    await settle();
    expect(controller.state.isAuthenticated, isTrue);
    expect(store.profile, isNotNull);
  }

  test(
    'end of access seen by any call signs out and wipes the cache',
    () async {
      await signedIn();
      // Not through restore: the router's revalidation got the refusal.
      events.ends.add(null);
      await settle();

      expect(store.wiped, <String>['server-user']);
      expect(store.profile, isNull);
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.message, AuthController.sessionExpiredMessage);
      expect(repository.signOuts, 0, reason: 'nothing is left to revoke');
    },
  );

  test('end of access during a restore wipes once', () async {
    await signedIn();
    repository.ended = true;
    await controller.restoreSession();
    await settle();

    expect(store.wiped, <String>['server-user']);
    expect(store.profile, isNull);
    expect(controller.state.isGuest, isTrue);
  });

  test('end of access on a cold start wipes the kept account', () async {
    store.profile = _user;
    repository.ended = true;
    await controller.restoreSession();
    await settle();

    expect(store.wiped, <String>['server-user']);
    expect(store.profile, isNull);
  });

  test('end of access before the profile was read still wipes it', () async {
    store.slowRead = Completer<AuthUserEntity?>();
    events.ends.add(null);
    await settle();
    store.slowRead!.complete(_user);
    await settle();

    expect(store.wiped, <String>['server-user']);
  });

  test(
    'an unconfirmed refusal forgets the profile and wipes nothing',
    () async {
      await signedIn();
      repository.failure = 'unauthenticated';
      await controller.restoreSession();
      await settle();

      expect(controller.state.isGuest, isTrue);
      expect(
        store.profile,
        isNull,
        reason: 'decision 4: not signed in offline',
      );
      expect(store.wiped, isEmpty);
    },
  );

  test('an unconfirmed refusal on a cold start forgets the profile', () async {
    store.profile = _user;
    repository.failure = 'unauthenticated';
    await controller.restoreSession();
    await settle();

    expect(store.profile, isNull);
    expect(store.wiped, isEmpty);
  });

  test('a lost SDK user forgets the profile and wipes nothing', () async {
    await signedIn();
    events.invalidations.add(null);
    await settle();

    expect(controller.state.isGuest, isTrue);
    expect(store.profile, isNull);
    expect(store.wiped, isEmpty);
  });

  for (final code in <String>[
    AuthController.offlineMessage,
    AuthController.rateLimitedMessage,
    AuthController.busyCode,
  ]) {
    test('$code keeps the profile and the cache', () async {
      await signedIn();
      repository.failure = code;
      await controller.restoreSession();
      await settle();

      expect(controller.state.isAuthenticated, isTrue);
      expect(store.profile, isNotNull);
      expect(store.wiped, isEmpty);
    });
  }

  test('a stale snapshot is no refusal: the profile stays', () async {
    await signedIn();
    repository.failure = 'SNAPSHOT_STALE';
    await controller.restoreSession();
    await settle();

    expect(store.profile, isNotNull);
    expect(store.wiped, isEmpty);
  });

  test('a sign-out during the profile read brings nobody back', () async {
    store.profile = _user;
    store.slowRead = Completer<AuthUserEntity?>();
    final restoring = controller.restoreSession();
    await controller.signOut();
    store.slowRead!.complete(_user);
    await restoring;
    store.slowRead = null;
    repository.failure = AuthController.offlineMessage;
    await controller.restoreSession();
    await settle();

    expect(controller.state.isOffline, isFalse);
    expect(controller.state.user, isNull);
  });

  test('sign-out forgets the profile and wipes nothing', () async {
    await signedIn();
    await controller.signOut();
    await settle();

    expect(store.profile, isNull);
    expect(store.wiped, isEmpty);
  });
}
