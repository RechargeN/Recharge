import 'package:recharge/app/di/booking_test_entry_guard.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/presentation/event_details_page.dart';
import 'package:recharge/app/application/active_creator_verification_provider.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/create/presentation/pages/create_hub_page.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/app/router/app_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/repositories/network_status.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/application/identity_workspace_providers.dart';
import 'package:recharge/features/notifications/application/notifications_providers.dart';
import '../unit/identity_access_guards_test.dart';

void main() {
  late GuardRepository repository;
  late RouterAuthRepository authRepository;
  late ProviderContainer container;
  setUp(() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues({});
    await setupDependencies();
    repository = GuardRepository(guardSnapshot());
    authRepository = RouterAuthRepository();
    await sl.unregister<IdentityWorkspaceRepository>();
    sl.registerSingleton<IdentityWorkspaceRepository>(repository);
    await sl.unregister<AuthRepository>();
    sl.registerSingleton<AuthRepository>(authRepository);
    container = ProviderContainer();
  });
  tearDown(() async {
    container.dispose();
    await sl.reset();
  });
  Future<void> open(
    WidgetTester tester,
    String path, {
    bool authenticated = true,
    bool settle = true,
  }) async {
    if (authenticated) {
      await container
          .read(authControllerProvider)
          .initializeCurrentUserFromCache();
    }
    final router = container.read(appRouterProvider);
    router.go(path);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
      return;
    }
    // A screen that keeps a spinner offline never settles.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  String location() =>
      container.read(appRouterProvider).routeInformationProvider.value.uri.path;

  testWidgets(
    'CP3 debug Booking route opens with .000Z query produced by toIso8601String',
    (tester) async {
      await sl.unregister<BookingTestEntryGuard>();
      sl.registerSingleton<BookingTestEntryGuard>(
        BookingTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: BookingBackendBindingController(
            emulatorBase: Uri.parse(
              'http://127.0.0.1:5001/demo-recharge/europe-west1',
            ),
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          ),
        ),
      );
      final uri = Uri(
        path: '${RouteNames.testEventBooking}/evt-1',
        queryParameters: {
          'occurrence': 'occ-1',
          'start': DateTime.utc(2026, 11, 20, 16).toIso8601String(),
          'end': DateTime.utc(2026, 11, 20, 18).toIso8601String(),
          'title': 'UTC route regression',
        },
      );
      await open(tester, uri.toString());
      expect(location(), '${RouteNames.testEventBooking}/evt-1');
      expect(find.byType(EventDetailsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ADR0023 User with zero pages retains personal Create hints', (
    tester,
  ) async {
    repository.snapshot = const IdentityAccessSnapshot(
      userId: 'alice',
      globalRole: 'user',
      creatorVerificationStatus: CreatorVerificationStatus.notStarted,
      globalCapabilities: {},
      pages: [],
      memberships: [],
      revision: 1,
    );
    await open(tester, RouteNames.create);
    final capabilities = container.read(activeCreateCapabilitiesProvider);
    expect(
      capabilities,
      containsAll(['create.place', 'create.route', 'create.collection']),
    );
    expect(location(), RouteNames.create);
    final hub = tester.widget<CreateHubPage>(find.byType(CreateHubPage));
    expect(
      hub.capabilities,
      containsAll(['create.place', 'create.route', 'create.collection']),
    );
  });
  testWidgets(
    'Create destination watches capability changes without recreating router',
    (tester) async {
      await open(tester, RouteNames.create);
      final router = container.read(appRouterProvider);
      repository.change(guardSnapshot(capabilities: {'create.rental'}));
      await tester.pumpAndSettle();
      expect(container.read(appRouterProvider), same(router));
      expect(
        tester.widget<CreateHubPage>(find.byType(CreateHubPage)).capabilities,
        contains('create.rental'),
      );
      repository.change(guardSnapshot(capabilities: {}));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CreateHubPage>(find.byType(CreateHubPage)).capabilities,
        isNot(contains('create.rental')),
      );
      expect(location(), RouteNames.create);
    },
  );
  testWidgets(
    'AUTH-ROT-02 temporary guest preserves Page workspace and route without authority',
    (tester) async {
      repository.workspace = WorkspaceRef.page('page-a');
      final auth = container.read(authControllerProvider);
      authRepository.restored = AuthResultEntity(
        user: authRepository.user!,
        session: AuthSessionEntity.serverIssued(
          sessionId: 'test',
          expiresAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 1)),
          serverSessionHandle: 'local-test',
          installationId: 'local-test',
        ),
      );
      await auth.restoreSession();
      await open(tester, RouteNames.professionalPage);
      final before = container
          .read(identityWorkspaceControllerProvider)
          .state
          .activeWorkspace;
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
      // Round 1 (2026-11-20): offline the user stays signed in, never authorized.
      expect(auth.state.isOffline, isTrue);
      expect(auth.state.isAuthenticated, isFalse);
      expect(auth.state.errorCode, AuthController.offlineMessage);
      expect(location(), RouteNames.professionalPage);
      expect(
        container
            .read(identityWorkspaceControllerProvider)
            .state
            .activeWorkspace,
        before,
      );
      expect(container.read(activeIdentityAccessProvider), isNull);
      authRepository.restored = AuthResultEntity(
        user: authRepository.user!,
        session: AuthSessionEntity.serverIssued(
          sessionId: 'refreshed',
          expiresAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          serverSessionHandle: 'local-test',
          installationId: 'local-test',
        ),
      );
      await auth.restoreSession();
      await tester.pumpAndSettle();
      expect(auth.state.isAuthenticated, isTrue);
      expect(location(), RouteNames.professionalPage);
      expect(
        container
            .read(identityWorkspaceControllerProvider)
            .state
            .activeWorkspace,
        before,
      );
      // Dispose the local test Session timer before Flutter checks invariants.
      authRepository.restored = null;
      await auth.signOut();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('protected redirect settles on safe destination without a loop', (
    tester,
  ) async {
    repository.snapshot = guardSnapshot(actor: 'foreign');
    await open(tester, RouteNames.adminTools);
    for (var i = 0; i < 3; i++) {
      container.read(appRouterProvider).refresh();
      await tester.pumpAndSettle();
    }
    expect(location(), RouteNames.settings);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'real app router restores cold Admin deep link with explicit capability',
    (tester) async {
      await open(tester, RouteNames.adminTools);
      expect(location(), RouteNames.adminTools);
      expect(find.text('Local/mock administration'), findsOneWidget);
      expect(
        container
            .read(identityWorkspaceControllerProvider)
            .state
            .activeWorkspace,
        WorkspaceRef.personal('alice'),
      );
    },
  );
  testWidgets(
    'Admin role without capability and non-Admin with capability are denied',
    (tester) async {
      repository.snapshot = guardSnapshot(capabilities: {});
      await open(tester, RouteNames.adminTools);
      expect(location(), RouteNames.settings);
      repository.change(guardSnapshot(role: 'user'));
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go(RouteNames.adminTools);
      await tester.pumpAndSettle();
      expect(location(), RouteNames.settings);
    },
  );
  testWidgets(
    'revocation while Admin screen is open redirects and clears protected content',
    (tester) async {
      await open(tester, RouteNames.adminTools);
      repository.change(guardSnapshot(capabilities: {}));
      await tester.pumpAndSettle();
      expect(location(), RouteNames.settings);
      expect(find.text('Local/mock administration'), findsNothing);
    },
  );
  testWidgets('Page A membership never opens foreign Page B deep link', (
    tester,
  ) async {
    await open(tester, RouteNames.professionalPagePreviewFor('page-b'));
    expect(location(), RouteNames.settings);
    expect(
      container.read(identityWorkspaceControllerProvider).state.activeWorkspace,
      WorkspaceRef.personal('alice'),
    );
  });
  testWidgets(
    'missing Page content capability blocks direct Page Create route',
    (tester) async {
      repository.snapshot = guardSnapshot(pageCapabilities: {'page.manage'});
      repository.workspace = WorkspaceRef.page('page-a');
      await open(tester, RouteNames.professionalPageCreate);
      expect(location(), RouteNames.settings);
    },
  );
  testWidgets(
    'logout clears Admin access and redirects; old snapshot cannot survive account switch',
    (tester) async {
      await open(tester, RouteNames.adminTools);
      await container.read(authControllerProvider).signOut();
      await tester.pumpAndSettle();
      expect(location(), RouteNames.signIn);
      expect(
        container
            .read(identityWorkspaceControllerProvider)
            .state
            .accessSnapshot,
        isNull,
      );
      authRepository.user = RouterAuthRepository.userFor('bob');
      repository.snapshot = guardSnapshot(
        actor: 'bob',
        role: 'user',
        capabilities: {},
      );
      await container
          .read(authControllerProvider)
          .initializeCurrentUserFromCache();
      container.read(appRouterProvider).go(RouteNames.adminTools);
      await tester.pumpAndSettle();
      expect(location(), RouteNames.settings);
      expect(
        container.read(identityWorkspaceControllerProvider).state.userId,
        'bob',
      );
    },
  );
  testWidgets(
    'signed-out deep link preserves safe path and query through sign-in',
    (tester) async {
      authRepository.user = null;
      await open(
        tester,
        '/page/public-preview/page-b?from=notification',
        authenticated: false,
      );
      final uri = container
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri;
      expect(uri.path, RouteNames.signIn);
      expect(
        uri.queryParameters['originRoute'],
        '/page/public-preview/page-b?from=notification',
      );
    },
  );
  testWidgets('revoked membership closes an already open Page workspace', (
    tester,
  ) async {
    repository.workspace = WorkspaceRef.page('page-a');
    await open(tester, RouteNames.professionalPage);
    expect(location(), RouteNames.professionalPage);
    expect(find.text('Private Page A'), findsWidgets);
    repository.change(
      guardSnapshot(membershipStatus: ManagedPageMembershipStatus.revoked),
    );
    await tester.pumpAndSettle();
    expect(location(), RouteNames.settings);
    expect(
      container.read(identityWorkspaceControllerProvider).state.activeWorkspace,
      WorkspaceRef.personal('alice'),
    );
    expect(find.text('Private Page A'), findsNothing);
  });
  for (final path in <String>[
    RouteNames.adminTools,
    RouteNames.professionalPage,
  ]) {
    testWidgets('OFFLINE-01: losing the network does not eject from $path', (
      tester,
    ) async {
      final network = RouterNetworkStatus();
      sl.registerSingleton<NetworkStatus>(network);
      repository.workspace = WorkspaceRef.page('page-a');
      if (path == RouteNames.adminTools) repository.workspace = null;
      await open(tester, path);
      expect(location(), path);

      // In dev and staging the access snapshot is a server read: offline it fails.
      repository.failReads = true;
      network.become(online: false);
      await tester.pumpAndSettle();

      expect(
        container.read(authControllerProvider).state.needsConnection,
        isTrue,
      );
      expect(location(), path);
    });
  }

  testWidgets('decision 5: the inbox in memory ends with the account', (
    tester,
  ) async {
    await open(tester, RouteNames.profile);
    final before = container.read(notificationsControllerProvider);

    await container.read(authControllerProvider).signOut();
    await tester.pumpAndSettle();

    expect(
      container.read(notificationsControllerProvider),
      isNot(same(before)),
    );
  });

  testWidgets('OFFLINE-01: the shell banner follows the network', (
    tester,
  ) async {
    final network = RouterNetworkStatus();
    sl.registerSingleton<NetworkStatus>(network);
    await open(tester, RouteNames.profile);
    expect(find.byKey(const Key('offline-banner')), findsNothing);

    network.become(online: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);

    network.become(online: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offline-banner')), findsNothing);
  });

  // Decision 2026-11-21 #4: a kept profile is not a permission.
  Future<void> openColdOffline(WidgetTester tester, String path) async {
    FlutterSecureStorage.setMockInitialValues({
      'auth.offlineProfile': '{"id":"alice","email":"alice@example.test"}',
    });
    sl.registerFactory<SignInWithGoogleUseCase>(
      () => SignInWithGoogleUseCase(OfflineFederatedAuth()),
    );
    authRepository.failure = const AuthException(
      code: AuthController.offlineMessage,
      message: AuthController.offlineMessage,
    );
    repository.failReads = true;
    await container.read(authControllerProvider).restoreSession();
    expect(container.read(authControllerProvider).state.isOffline, isTrue);
    await open(tester, path, authenticated: false, settle: false);
  }

  Future<void> stopRetries(WidgetTester tester) async {
    authRepository.failure = null;
    await container.read(authControllerProvider).signOut();
    await tester.pumpAndSettle();
  }

  for (final path in <String>[
    RouteNames.adminTools,
    RouteNames.routeModeration,
    RouteNames.professionalPage,
    RouteNames.professionalPageAccount,
    RouteNames.professionalPagePreviewFor('page-a'),
  ]) {
    testWidgets('offline cold start cannot open $path', (tester) async {
      await openColdOffline(tester, path);
      expect(location(), RouteNames.settings);
      await stopRetries(tester);
    });
  }

  for (final path in <String>[RouteNames.favorites, RouteNames.profile]) {
    testWidgets('offline cold start keeps the saved screen $path', (
      tester,
    ) async {
      await openColdOffline(tester, path);
      expect(location(), path);
      await stopRetries(tester);
    });
  }

  testWidgets('offline after the snapshot: no new privileged navigation', (
    tester,
  ) async {
    authRepository.restored = AuthResultEntity(
      user: authRepository.user!,
      session: AuthSessionEntity.serverIssued(
        sessionId: 'test',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 1)),
        serverSessionHandle: 'local-test',
        installationId: 'local-test',
      ),
    );
    await container.read(authControllerProvider).restoreSession();
    await open(tester, RouteNames.profile, authenticated: false);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(container.read(authControllerProvider).state.isOffline, isTrue);

    container.read(appRouterProvider).go(RouteNames.adminTools);
    await tester.pumpAndSettle();
    expect(location(), RouteNames.settings);
    authRepository.restored = null;
    await stopRetries(tester);
  });

  testWidgets('Saved is read again when the connection is back', (
    tester,
  ) async {
    final network = RouterNetworkStatus();
    sl.registerSingleton<NetworkStatus>(network);
    final favorites = CountingFavorites();
    await sl.unregister<FavoritesRepository>();
    sl.registerSingleton<FavoritesRepository>(favorites);
    await open(tester, RouteNames.favorites);
    final before = favorites.reads;
    expect(before, greaterThan(0));
    network.become(online: false);
    await tester.pumpAndSettle();
    expect(favorites.reads, before);

    network.become(online: true);
    await tester.pumpAndSettle();
    expect(favorites.reads, before + 1);
  });

  testWidgets('failed fresh read denies protected route', (tester) async {
    repository.failReads = true;
    await open(tester, RouteNames.adminTools);
    expect(location(), RouteNames.settings);
    expect(find.text('Local/mock administration'), findsNothing);
  });
}

class RouterNetworkStatus implements NetworkStatus {
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get changes => _changes.stream;

  void become({required bool online}) {
    _online = online;
    _changes.add(online);
  }
}

class CountingFavorites implements FavoritesRepository {
  int reads = 0;

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async {
    reads++;
    return const <FavoriteItemEntity>[];
  }

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {}

  @override
  Future<void> removeFavorite(String itemId) async {}
}

class OfflineFederatedAuth implements FederatedAuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RouterAuthRepository implements AuthRepository {
  AuthException? failure;
  AuthResultEntity? restored;
  AuthUserEntity? user = userFor('alice');
  static AuthUserEntity userFor(String id) => AuthUserEntity(
    id: id,
    email: '$id@example.test',
    role: 'admin',
    capabilities: const [],
    profileStatus: 'active',
  );
  @override
  Future<AuthUserEntity?> getCurrentUser() async => user;
  @override
  Future<void> signOut() async {
    user = null;
  }

  @override
  Future<AuthResultEntity?> restoreSession() async {
    if (failure != null) throw failure!;
    return restored;
  }

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async => throw UnimplementedError();
}
