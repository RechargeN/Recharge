import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/identity/account_experience.dart';
import 'package:recharge/core/notifications/app_notification_sink.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/identity/application/controllers/identity_workspace_controller.dart';
import 'package:recharge/features/identity/application/state/identity_workspace_state.dart';
import 'package:recharge/features/identity/data/datasources/mock_identity_fixture.dart';
import 'package:recharge/features/identity/domain/entities/admin_experience_preview.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/professional_page_creation_input.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/usecases/create_professional_page_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/request_page_limit_increase_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/select_workspace_usecase.dart';

void main() {
  const String userId = 'demo_full_access';

  test('default Admin fixture starts with zero invented pages', () async {
    final repository = _MemoryIdentityWorkspaceRepository(
      const MockIdentityFixture().accessForUser(userId),
    );

    final result = await LoadIdentityWorkspaceUseCase(repository)(userId);

    expect(result.activeWorkspace, WorkspaceRef.personal(userId));
    expect(result.recoveryReasonCode, isNull);
    expect(result.accessSnapshot.globalRole, 'admin');
    expect(result.accessSnapshot.isVerifiedCreator, isTrue);
    expect(result.accessSnapshot.availablePages, isEmpty);
    expect(
      result.accessSnapshot.hasGlobalCapability('admin.experience.preview'),
      isTrue,
    );
  });

  test('selects and restores an explicitly created page', () async {
    final repository = _MemoryIdentityWorkspaceRepository(
      _accessWithPageCount(1, userId: userId),
    );
    final selected = WorkspaceRef.page('page-0');

    await SelectWorkspaceUseCase(repository)(
      userId: userId,
      workspace: selected,
    );
    final restored = await LoadIdentityWorkspaceUseCase(repository)(userId);

    expect(repository.savedWorkspace, selected);
    expect(restored.activeWorkspace, selected);
  });

  test('page A access never authorizes unavailable page B', () async {
    final repository = _MemoryIdentityWorkspaceRepository(
      _accessWithPageCount(1, userId: userId),
    );

    await expectLater(
      () => SelectWorkspaceUseCase(repository)(
        userId: userId,
        workspace: WorkspaceRef.page('page-b'),
      ),
      throwsA(
        isA<WorkspaceSelectionException>().having(
          (WorkspaceSelectionException error) => error.code,
          'code',
          'workspace_access_unavailable',
        ),
      ),
    );
    expect(repository.savedWorkspace, isNull);
  });

  test(
    'revoked saved page falls back to personal and repairs preference',
    () async {
      final IdentityAccessSnapshot access = _accessWithPageCount(
        1,
        userId: userId,
        membershipStatus: ManagedPageMembershipStatus.revoked,
      );
      final repository = _MemoryIdentityWorkspaceRepository(
        access,
        savedWorkspace: WorkspaceRef.page('page-0'),
      );

      final result = await LoadIdentityWorkspaceUseCase(repository)(userId);

      expect(result.activeWorkspace, WorkspaceRef.personal(userId));
      expect(result.recoveryReasonCode, 'workspace_access_unavailable');
      expect(repository.savedWorkspace, WorkspaceRef.personal(userId));
    },
  );

  test('available page projection supports zero, one and three pages', () {
    expect(_accessWithPageCount(0).availablePages, isEmpty);
    expect(_accessWithPageCount(1).availablePages, hasLength(1));
    expect(_accessWithPageCount(3).availablePages, hasLength(3));
  });

  test('creates pages one through three and blocks page four', () async {
    final repository = _MemoryIdentityWorkspaceRepository(
      const MockIdentityFixture().accessForUser(userId),
    );
    final useCase = CreateProfessionalPageUseCase(
      repository: repository,
      idGenerator: _SequenceIdGenerator(),
      utcNow: () => DateTime.utc(2026, 7, 31, 12),
    );

    for (int index = 1; index <= 3; index += 1) {
      await useCase(userId: userId, input: _creationInput('User Page $index'));
    }

    expect(
      (await repository.loadAccessSnapshot(userId)).ownedPages,
      hasLength(3),
    );
    await expectLater(
      () => useCase(userId: userId, input: _creationInput('Blocked Page')),
      throwsA(
        isA<CreateProfessionalPageException>().having(
          (CreateProfessionalPageException error) => error.code,
          'code',
          'self_service_page_limit_reached',
        ),
      ),
    );
    expect(
      (await repository.loadAccessSnapshot(userId)).ownedPages,
      hasLength(3),
    );
  });

  test('additional-page request is pending and idempotent', () async {
    final repository = _MemoryIdentityWorkspaceRepository(
      _accessWithPageCount(3, userId: userId),
    );
    final useCase = RequestPageLimitIncreaseUseCase(
      repository: repository,
      idGenerator: _SequenceIdGenerator(),
      utcNow: () => DateTime.utc(2026, 7, 31, 13),
    );

    final first = await useCase(userId);
    final second = await useCase(userId);

    expect(first.id, second.id);
    expect(first.status, PageLimitIncreaseRequestStatus.pending);
    expect(first.requestedOwnedPageLimit, 4);
    expect(repository.limitRequests, hasLength(1));
  });

  test(
    'controller creates a page and Admin preview changes UI state only',
    () async {
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
          utcNow: () => DateTime.utc(2026, 7, 31, 14),
        ),
        requestPageLimitIncreaseUseCase: RequestPageLimitIncreaseUseCase(
          repository: repository,
          idGenerator: ids,
          utcNow: () => DateTime.utc(2026, 7, 31, 14),
        ),
        notificationSink: notifications,
        marketConfig: MarketConfig.riga,
        analyticsService: _NoopAnalyticsService(),
      );

      await controller.ensureLoaded(userId);
      expect(controller.state.status, IdentityWorkspaceStatus.ready);
      expect(
        controller.selectAdminPreview(AdminExperiencePreview.viewer),
        isTrue,
      );
      expect(controller.state.effectiveExperience, AccountExperience.viewer);
      expect(controller.state.activeWorkspace, WorkspaceRef.personal(userId));

      final success = await controller.createProfessionalPage(
        displayName: 'Created by user',
        kind: ManagedPageKind.organization,
      );

      expect(success, isTrue);
      expect(controller.state.accessSnapshot!.ownedPages, hasLength(1));
      expect(controller.state.activeWorkspace!.isPage, isTrue);
      expect(
        controller.state.effectiveExperience,
        AccountExperience.professionalPage,
      );
      expect(notifications.events, hasLength(2));
    },
  );
}

ProfessionalPageCreationInput _creationInput(String displayName) {
  return ProfessionalPageCreationInput(
    kind: ManagedPageKind.company,
    displayName: displayName,
    marketId: 'riga',
    countryCode: 'LV',
    defaultLocale: 'en',
    timezone: 'Europe/Riga',
    defaultCurrency: 'EUR',
    supportedLocales: const <String>['en', 'lv', 'ru'],
  );
}

IdentityAccessSnapshot _accessWithPageCount(
  int count, {
  String userId = 'page_count_user',
  ManagedPageMembershipStatus membershipStatus =
      ManagedPageMembershipStatus.active,
}) {
  final pages = List<ManagedPageEntity>.generate(
    count,
    (int index) => ManagedPageEntity(
      id: 'page-$index',
      ownerUserId: userId,
      kind: ManagedPageKind.company,
      displayName: 'Page $index',
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
  );
  final memberships = pages
      .map(
        (ManagedPageEntity page) => ManagedPageMembershipEntity(
          pageId: page.id,
          userId: userId,
          relationship: ManagedPageRelationship.owner,
          status: membershipStatus,
          capabilities: const <String>{'page.content.create'},
          revision: 1,
        ),
      )
      .toList(growable: false);
  return IdentityAccessSnapshot(
    userId: userId,
    globalRole: 'admin',
    creatorVerificationStatus: CreatorVerificationStatus.verified,
    globalCapabilities: const <String>{
      'page.create',
      'admin.tools.view',
      'admin.experience.preview',
    },
    pages: pages,
    memberships: memberships,
    revision: 1,
  );
}

class _MemoryIdentityWorkspaceRepository
    implements IdentityWorkspaceRepository {
  _MemoryIdentityWorkspaceRepository(
    this.accessSnapshot, {
    this.savedWorkspace,
  });

  IdentityAccessSnapshot accessSnapshot;
  WorkspaceRef? savedWorkspace;
  final List<PageLimitIncreaseRequestEntity> limitRequests =
      <PageLimitIncreaseRequestEntity>[];

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async {
    return accessSnapshot;
  }

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async {
    return savedWorkspace;
  }

  @override
  Future<void> saveActiveWorkspace(
    String userId,
    WorkspaceRef workspace,
  ) async {
    savedWorkspace = workspace;
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
    for (final PageLimitIncreaseRequestEntity request
        in limitRequests.reversed) {
      if (request.userId == userId && request.isPending) return request;
    }
    return null;
  }

  @override
  Future<void> savePageLimitRequest(
    PageLimitIncreaseRequestEntity request,
  ) async {
    if (limitRequests.any(
      (PageLimitIncreaseRequestEntity item) => item.id == request.id,
    )) {
      return;
    }
    limitRequests.add(request);
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
