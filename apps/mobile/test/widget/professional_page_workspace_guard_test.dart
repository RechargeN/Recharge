import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/notifications/app_notification_sink.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/identity/application/controllers/identity_workspace_controller.dart';
import 'package:recharge/features/identity/application/identity_workspace_providers.dart';
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
import 'package:recharge/features/identity/presentation/pages/professional_page_workspace_page.dart';

/// IDP-05A negative coverage: a page surface must never render a page the
/// user can no longer activate, even when the stored active workspace still
/// points at it (stale preference, deep link, revoked membership).
void main() {
  const String userId = 'user-1';

  Future<IdentityWorkspaceController> loadedController(
    _Repository repository,
  ) async {
    final _Ids ids = _Ids();
    final IdentityWorkspaceController controller = IdentityWorkspaceController(
      loadIdentityWorkspaceUseCase: LoadIdentityWorkspaceUseCase(repository),
      selectWorkspaceUseCase: SelectWorkspaceUseCase(repository),
      createProfessionalPageUseCase: CreateProfessionalPageUseCase(
        repository: repository,
        idGenerator: ids,
        utcNow: () => DateTime.utc(2026, 7, 31, 14),
      ),
      requestPageLimitIncreaseUseCase: RequestPageLimitIncreaseUseCase(
        repository: repository,
        idGenerator: ids,
        utcNow: () => DateTime.utc(2026, 7, 31, 14),
      ),
      notificationSink: _Sink(),
      marketConfig: MarketConfig.riga,
      analyticsService: _Analytics(),
    );
    await controller.ensureLoaded(userId);
    return controller;
  }

  Widget app(IdentityWorkspaceController controller) {
    return ProviderScope(
      overrides: <Override>[
        identityWorkspaceControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(
        home: ProfessionalPageWorkspacePage(
          section: ProfessionalPageSection.content,
        ),
      ),
    );
  }

  testWidgets('an accessible active page is rendered', (tester) async {
    final _Repository repository = _Repository(
      _snapshot(ManagedPageMembershipStatus.active),
      WorkspaceRef.page('page-1'),
    );
    final IdentityWorkspaceController controller = await loadedController(
      repository,
    );

    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Page One'), findsOneWidget);
    expect(find.text('Professional Page preview'), findsNothing);
  });

  testWidgets('a revoked page is never rendered and the workspace resets', (
    tester,
  ) async {
    final _Repository repository = _Repository(
      _snapshot(ManagedPageMembershipStatus.active),
      WorkspaceRef.page('page-1'),
    );
    final IdentityWorkspaceController controller = await loadedController(
      repository,
    );
    expect(controller.state.activeWorkspace, WorkspaceRef.page('page-1'));

    // Access is revoked after the controller loaded; the page stays "active"
    // in memory until the surface opens and re-validates.
    repository.snapshot = _snapshot(ManagedPageMembershipStatus.revoked);

    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Page One'), findsNothing);
    expect(find.text('Professional Page preview'), findsOneWidget);
    expect(controller.state.activeWorkspace, WorkspaceRef.personal(userId));
    expect(repository.saved, WorkspaceRef.personal(userId));
  });
}

IdentityAccessSnapshot _snapshot(ManagedPageMembershipStatus status) {
  return IdentityAccessSnapshot(
    userId: 'user-1',
    globalRole: 'user',
    creatorVerificationStatus: CreatorVerificationStatus.verified,
    globalCapabilities: const <String>{},
    pages: <ManagedPageEntity>[
      ManagedPageEntity(
        id: 'page-1',
        ownerUserId: 'user-1',
        kind: ManagedPageKind.company,
        displayName: 'Page One',
        avatar: '',
        verificationStatus: ManagedPageVerificationStatus.pending,
        lifecycle: ManagedPageLifecycle.active,
        marketId: 'riga',
        countryCode: 'LV',
        defaultLocale: 'en',
        timezone: 'Europe/Riga',
        defaultCurrency: 'EUR',
        supportedLocales: const <String>['en'],
        createdAtUtc: DateTime.utc(2026, 7, 31),
        revision: 1,
      ),
    ],
    memberships: <ManagedPageMembershipEntity>[
      ManagedPageMembershipEntity(
        pageId: 'page-1',
        userId: 'user-1',
        relationship: ManagedPageRelationship.owner,
        status: status,
        capabilities: const <String>{'page.content.submit'},
        revision: 1,
      ),
    ],
    revision: 1,
  );
}

class _Repository implements IdentityWorkspaceRepository {
  _Repository(this.snapshot, this.saved);

  IdentityAccessSnapshot snapshot;
  WorkspaceRef? saved;

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async =>
      snapshot;

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async => saved;

  @override
  Future<void> saveActiveWorkspace(
    String userId,
    WorkspaceRef workspace,
  ) async {
    saved = workspace;
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
  ) async => null;

  @override
  Future<void> savePageLimitRequest(
    PageLimitIncreaseRequestEntity request,
  ) async {}
}

class _Ids implements IdGenerator {
  @override
  String generate() => '00000000-0000-4000-8000-000000000001';
}

class _Sink implements AppNotificationSink {
  @override
  Future<void> appendNotification(AppNotificationEvent event) async {}
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
