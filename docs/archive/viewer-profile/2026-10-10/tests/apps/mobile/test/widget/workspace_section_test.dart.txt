import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/notifications/app_notification_sink.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/identity/application/controllers/identity_workspace_controller.dart';
import 'package:recharge/features/identity/application/identity_workspace_providers.dart';
import 'package:recharge/features/identity/data/datasources/mock_identity_fixture.dart';
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
import 'package:recharge/features/identity/presentation/widgets/workspace_section.dart';

void main() {
  testWidgets(
    'starts empty, exposes Admin preview and creates only a user page',
    (WidgetTester tester) async {
      const String userId = 'demo_full_access';
      final repository = _MemoryIdentityWorkspaceRepository(
        const MockIdentityFixture().accessForUser(userId),
      );
      final notifications = _MemoryNotificationSink();
      final ids = _SequenceIdGenerator();
      final controller = IdentityWorkspaceController(
        loadIdentityWorkspaceUseCase: LoadIdentityWorkspaceUseCase(repository),
        selectWorkspaceUseCase: SelectWorkspaceUseCase(repository),
        createProfessionalPageUseCase: CreateProfessionalPageUseCase(
          repository: repository,
          idGenerator: ids,
          utcNow: () => DateTime.utc(2026, 7, 31, 15),
        ),
        requestPageLimitIncreaseUseCase: RequestPageLimitIncreaseUseCase(
          repository: repository,
          idGenerator: ids,
          utcNow: () => DateTime.utc(2026, 7, 31, 15),
        ),
        notificationSink: notifications,
        marketConfig: MarketConfig.riga,
        analyticsService: _NoopAnalyticsService(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            identityWorkspaceControllerProvider.overrideWith(
              (Ref ref) => controller,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: WorkspaceSection(userId: userId),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal profile'), findsOneWidget);
      expect(
        find.text('You have not created a Professional Page yet.'),
        findsOneWidget,
      );
      expect(find.text('Baltic Events'), findsNothing);
      expect(find.text('Riga Coffee Group'), findsNothing);
      expect(find.text('Weekend Latvia'), findsNothing);
      expect(
        find.byKey(const ValueKey('admin-preview-viewer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-preview-creator')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-preview-professionalPage')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('admin-preview-professionalPage')),
      );
      await tester.pump();
      expect(controller.state.adminPreview?.name, 'professionalPage');
      expect(controller.state.activeWorkspace, WorkspaceRef.personal(userId));

      await tester.ensureVisible(
        find.byKey(const ValueKey('empty-create-professional-page')),
      );
      await tester.tap(
        find.byKey(const ValueKey('empty-create-professional-page')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('professional-page-name')),
        'User Created Page',
      );
      await tester.tap(find.byKey(const ValueKey('submit-professional-page')));
      await tester.pumpAndSettle();

      expect(find.text('User Created Page'), findsOneWidget);
      expect(find.text('1 of 3 self-service pages used'), findsOneWidget);
      expect(controller.state.activeWorkspace?.isPage, isTrue);
      expect(controller.state.accessSnapshot!.ownedPages, hasLength(1));
      expect(notifications.events, hasLength(2));
    },
  );
}

class _MemoryIdentityWorkspaceRepository
    implements IdentityWorkspaceRepository {
  _MemoryIdentityWorkspaceRepository(this.accessSnapshot);

  IdentityAccessSnapshot accessSnapshot;
  WorkspaceRef? activeWorkspace;
  PageLimitIncreaseRequestEntity? pendingRequest;

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
  }) async {
    accessSnapshot = IdentityAccessSnapshot(
      userId: accessSnapshot.userId,
      globalRole: accessSnapshot.globalRole,
      creatorVerificationStatus: accessSnapshot.creatorVerificationStatus,
      globalCapabilities: accessSnapshot.globalCapabilities,
      pages: <ManagedPageEntity>[...accessSnapshot.pages, page],
      memberships: <ManagedPageMembershipEntity>[
        ...accessSnapshot.memberships,
        membership,
      ],
      revision: accessSnapshot.revision + 1,
    );
  }

  @override
  Future<PageLimitIncreaseRequestEntity?> loadPendingPageLimitRequest(
    String userId,
  ) async {
    return pendingRequest;
  }

  @override
  Future<void> savePageLimitRequest(
    PageLimitIncreaseRequestEntity request,
  ) async {
    pendingRequest ??= request;
  }
}

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() =>
      '00000000-0000-4000-8000-${(++_next).toString().padLeft(12, '0')}';
}

class _MemoryNotificationSink implements AppNotificationSink {
  final List<AppNotificationEvent> events = <AppNotificationEvent>[];

  @override
  Future<void> appendNotification(AppNotificationEvent event) async {
    if (events.any((AppNotificationEvent item) => item.id == event.id)) return;
    events.add(event);
  }
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
