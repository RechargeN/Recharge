import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/app/presentation/recharge_app_shell.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/notifications/app_notification_sink.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/identity/application/controllers/identity_workspace_controller.dart';
import 'package:recharge/features/identity/application/identity_workspace_providers.dart';
import 'package:recharge/features/identity/data/datasources/mock_identity_fixture.dart';
import 'package:recharge/features/identity/domain/entities/admin_experience_preview.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/usecases/create_professional_page_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/request_page_limit_increase_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/select_workspace_usecase.dart';

void main() {
  testWidgets(
    'Admin Professional Page preview uses page navigation without fake page',
    (WidgetTester tester) async {
      const String userId = 'demo_full_access';
      final repository = _ShellIdentityRepository(
        const MockIdentityFixture().accessForUser(userId),
      );
      final ids = _UnusedIdGenerator();
      final controller = IdentityWorkspaceController(
        loadIdentityWorkspaceUseCase: LoadIdentityWorkspaceUseCase(repository),
        selectWorkspaceUseCase: SelectWorkspaceUseCase(repository),
        createProfessionalPageUseCase: CreateProfessionalPageUseCase(
          repository: repository,
          idGenerator: ids,
        ),
        requestPageLimitIncreaseUseCase: RequestPageLimitIncreaseUseCase(
          repository: repository,
          idGenerator: ids,
        ),
        notificationSink: _NoopNotificationSink(),
        marketConfig: MarketConfig.riga,
        analyticsService: _NoopAnalyticsService(),
      );
      await controller.ensureLoaded(userId);
      controller.selectAdminPreview(AdminExperiencePreview.professionalPage);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            identityWorkspaceControllerProvider.overrideWith(
              (Ref ref) => controller,
            ),
          ],
          child: _ProfessionalShellApp(userId: userId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bottom-nav-page')), findsOneWidget);
      expect(find.byKey(const Key('bottom-nav-content')), findsOneWidget);
      expect(find.byKey(const Key('bottom-nav-create')), findsOneWidget);
      expect(find.byKey(const Key('bottom-nav-account')), findsOneWidget);
      expect(find.byKey(const Key('bottom-nav-smart-search')), findsNothing);
      expect(find.text('Professional preview'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bottom-nav-content')));
      await tester.pumpAndSettle();
      expect(find.text('Content preview'), findsOneWidget);
      expect(controller.state.accessSnapshot!.pages, isEmpty);
      expect(controller.state.activeWorkspace, WorkspaceRef.personal(userId));
    },
  );
}

class _ProfessionalShellApp extends StatelessWidget {
  const _ProfessionalShellApp({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: RouteNames.professionalPage,
        routes: <RouteBase>[
          ShellRoute(
            builder: (BuildContext context, GoRouterState state, Widget child) {
              return RechargeAppShell(
                currentLocation: state.uri.path,
                userId: userId,
                child: child,
              );
            },
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.professionalPage,
                builder: (context, state) =>
                    const _ShellBody('Professional preview'),
              ),
              GoRoute(
                path: RouteNames.professionalPageContent,
                builder: (context, state) =>
                    const _ShellBody('Content preview'),
              ),
              GoRoute(
                path: RouteNames.professionalPageCreate,
                builder: (context, state) => const _ShellBody('Create preview'),
              ),
              GoRoute(
                path: RouteNames.notifications,
                builder: (context, state) =>
                    const _ShellBody('Notifications preview'),
              ),
              GoRoute(
                path: RouteNames.professionalPageAccount,
                builder: (context, state) =>
                    const _ShellBody('Account preview'),
              ),
              GoRoute(
                path: RouteNames.discover,
                builder: (context, state) => const _ShellBody('Home'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShellBody extends StatelessWidget {
  const _ShellBody(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}

class _ShellIdentityRepository implements IdentityWorkspaceRepository {
  _ShellIdentityRepository(this.accessSnapshot);

  final IdentityAccessSnapshot accessSnapshot;
  WorkspaceRef? activeWorkspace;

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async {
    return accessSnapshot;
  }

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async {
    return activeWorkspace;
  }

  @override
  Future<void> saveActiveWorkspace(
    String userId,
    WorkspaceRef workspace,
  ) async {
    activeWorkspace = workspace;
  }

  @override
  Future<void> saveCreatedPage({
    required String userId,
    required ManagedPageEntity page,
    required ManagedPageMembershipEntity membership,
  }) async {}

  @override
  Future<PageLimitIncreaseRequestEntity?> loadPendingPageLimitRequest(
    String userId,
  ) async {
    return null;
  }

  @override
  Future<void> savePageLimitRequest(
    PageLimitIncreaseRequestEntity request,
  ) async {}
}

class _UnusedIdGenerator implements IdGenerator {
  @override
  String generate() => '00000000-0000-4000-8000-000000000001';
}

class _NoopNotificationSink implements AppNotificationSink {
  @override
  Future<void> appendNotification(AppNotificationEvent event) async {}
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
