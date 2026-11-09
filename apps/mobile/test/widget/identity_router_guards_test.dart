import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/router/app_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/application/identity_workspace_providers.dart';
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
    await tester.pumpAndSettle();
  }

  String location() =>
      container.read(appRouterProvider).routeInformationProvider.value.uri.path;

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
  testWidgets('failed fresh read denies protected route', (tester) async {
    repository.failReads = true;
    await open(tester, RouteNames.adminTools);
    expect(location(), RouteNames.settings);
    expect(find.text('Local/mock administration'), findsNothing);
  });
}

class RouterAuthRepository implements AuthRepository {
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
  Future<AuthResultEntity?> restoreSession() async => null;
  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async => throw UnimplementedError();
}
