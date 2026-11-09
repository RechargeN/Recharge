import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:recharge/features/identity/data/datasources/identity_workspace_local_datasource.dart';
import 'package:recharge/features/identity/data/repositories/identity_workspace_repository_impl.dart';
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
  regressionCases();
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
        await controller.selectAdminPreview(AdminExperiencePreview.viewer),
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
  test(
    'revalidateAccess drops a revoked active page back to personal',
    () async {
      final repository = _MemoryIdentityWorkspaceRepository(
        _accessWithPageCount(1, userId: userId),
        savedWorkspace: WorkspaceRef.page('page-0'),
      );
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
        notificationSink: _MemoryNotificationSink(),
        marketConfig: MarketConfig.riga,
        analyticsService: _NoopAnalyticsService(),
      );
      addTearDown(controller.dispose);
      await controller.ensureLoaded(userId);
      expect(controller.state.activeWorkspace, WorkspaceRef.page('page-0'));
      expect(await controller.revalidateAccess(), isFalse);

      repository.accessSnapshot = _accessWithPageCount(
        1,
        userId: userId,
        membershipStatus: ManagedPageMembershipStatus.revoked,
      );

      expect(await controller.revalidateAccess(), isTrue);
      expect(controller.state.activeWorkspace, WorkspaceRef.personal(userId));
      expect(controller.state.accessSnapshot!.availablePages, isEmpty);
      expect(repository.savedWorkspace, WorkspaceRef.personal(userId));
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

void regressionCases() {
  test(
    'creation retry after notification failure reuses page and event ids',
    () async {
      final repo = _MemoryIdentityWorkspaceRepository(
        _accessWithPageCount(0, userId: 'alice'),
      );
      final sink = _FailingOnceNotificationSink();
      final controller = _controller(repo, sink: sink);
      addTearDown(controller.dispose);
      await controller.ensureLoaded('alice');
      expect(
        await controller.createProfessionalPage(
          displayName: 'Retry page',
          kind: ManagedPageKind.company,
        ),
        isFalse,
      );
      expect(repo.accessSnapshot.pages, hasLength(1));
      expect(
        await controller.createProfessionalPage(
          displayName: 'Retry page',
          kind: ManagedPageKind.company,
        ),
        isTrue,
      );
      expect(repo.accessSnapshot.pages, hasLength(1));
      expect(sink.events, hasLength(2));
      expect(
        sink.events
            .where((e) => e.audience == AppNotificationAudience.user)
            .single
            .recipientUserId,
        'alice',
      );
    },
  );
  test(
    'two repository instances cannot exceed durable ownership quota',
    () async {
      const data = IdentityWorkspaceLocalDataSource(FlutterSecureStorage());
      final initial = _accessWithPageCount(2, userId: 'alice');
      await data.saveManagedPageRecord(
        'alice',
        IdentityManagedPageLocalRecord(
          pages: initial.pages,
          memberships: initial.memberships,
        ),
      );
      final first = IdentityWorkspaceRepositoryImpl(
        localDataSource: data,
        mockFixture: const MockIdentityFixture(),
      );
      final second = IdentityWorkspaceRepositoryImpl(
        localDataSource: data,
        mockFixture: const MockIdentityFixture(),
      );
      final ids = _SequenceIdGenerator();
      final results = await Future.wait(
        [first, second].map(
          (repo) =>
              CreateProfessionalPageUseCase(repository: repo, idGenerator: ids)(
                userId: 'alice',
                input: _creationInput('Concurrent'),
              ).then<Object>((page) => page, onError: (Object error) => error),
        ),
      );
      expect(results.whereType<ManagedPageEntity>(), hasLength(1));
      expect(
        (await first.loadAccessSnapshot('alice')).ownedPages,
        hasLength(3),
      );
    },
  );
  test('two repository instances return the same pending request', () async {
    const data = IdentityWorkspaceLocalDataSource(FlutterSecureStorage());
    final initial = _accessWithPageCount(3, userId: 'alice');
    await data.saveManagedPageRecord(
      'alice',
      IdentityManagedPageLocalRecord(
        pages: initial.pages,
        memberships: initial.memberships,
      ),
    );
    final ids = _SequenceIdGenerator();
    final results = await Future.wait(
      List.generate(
        2,
        (_) => RequestPageLimitIncreaseUseCase(
          repository: IdentityWorkspaceRepositoryImpl(
            localDataSource: data,
            mockFixture: const MockIdentityFixture(),
          ),
          idGenerator: ids,
        )('alice'),
      ),
    );
    expect(results.map((r) => r.id).toSet(), hasLength(1));
    expect(
      (await data.loadManagedPageRecord('alice')).limitRequests,
      hasLength(1),
    );
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'R09 actual repository concurrent requests use one canonical id',
    () async {
      const data = IdentityWorkspaceLocalDataSource(FlutterSecureStorage());
      final access = _accessWithPageCount(3, userId: 'alice');
      await data.saveManagedPageRecord(
        'alice',
        IdentityManagedPageLocalRecord(
          pages: access.pages,
          memberships: access.memberships,
          limitRequests: [],
        ),
      );
      final repo = IdentityWorkspaceRepositoryImpl(
        localDataSource: data,
        mockFixture: const MockIdentityFixture(),
      );
      final request = RequestPageLimitIncreaseUseCase(
        repository: repo,
        idGenerator: _SequenceIdGenerator(),
      );
      final results = await Future.wait([request('alice'), request('alice')]);
      expect(results.map((r) => r.id).toSet(), hasLength(1));
    },
  );
  test(
    'R10 actual repository retains every successfully returned page',
    () async {
      const data = IdentityWorkspaceLocalDataSource(FlutterSecureStorage());
      final access = _accessWithPageCount(1, userId: 'alice');
      await data.saveManagedPageRecord(
        'alice',
        IdentityManagedPageLocalRecord(
          pages: access.pages,
          memberships: access.memberships,
          limitRequests: [],
        ),
      );
      final repo = IdentityWorkspaceRepositoryImpl(
        localDataSource: data,
        mockFixture: const MockIdentityFixture(),
      );
      final create = CreateProfessionalPageUseCase(
        repository: repo,
        idGenerator: _SequenceIdGenerator(),
      );
      final results = await Future.wait([
        create(userId: 'alice', input: _creationInput('Second')),
        create(userId: 'alice', input: _creationInput('Third')),
      ]);
      final restored = await repo.loadAccessSnapshot('alice');
      expect(
        restored.pages.map((p) => p.id),
        containsAll(results.map((p) => p.id)),
      );
    },
  );
  test('P01 Admin preview leaves authority and workspace unchanged', () async {
    final repo = _MemoryIdentityWorkspaceRepository(
      _accessWithPageCount(1, userId: 'alice'),
    );
    final controller = _controller(repo);
    addTearDown(controller.dispose);
    await controller.ensureLoaded('alice');
    final snapshot = controller.state.accessSnapshot;
    final workspace = controller.state.activeWorkspace;
    for (final preview in AdminExperiencePreview.values) {
      expect(await controller.selectAdminPreview(preview), isTrue);
      expect(
        controller.state.accessSnapshot!.globalRole == snapshot!.globalRole &&
            controller.state.accessSnapshot!.globalCapabilities.containsAll(
              snapshot.globalCapabilities,
            ),
        isTrue,
      );
      expect(controller.state.activeWorkspace, workspace);
      expect(repo.savedWorkspace, isNull);
    }
  });

  test('R01 owned quota must survive revoked membership', () async {
    final repo = _MemoryIdentityWorkspaceRepository(
      _accessWithPageCount(
        3,
        userId: 'alice',
        membershipStatus: ManagedPageMembershipStatus.revoked,
      ),
    );
    final create = CreateProfessionalPageUseCase(
      repository: repo,
      idGenerator: _SequenceIdGenerator(),
    );
    await expectLater(
      create(userId: 'alice', input: _creationInput('Fourth')),
      throwsA(isA<CreateProfessionalPageException>()),
    );
  });
  test(
    'R02 concurrent fourth-page requests return one pending request',
    () async {
      final repo = _MemoryIdentityWorkspaceRepository(
        _accessWithPageCount(3, userId: 'alice'),
      );
      final request = RequestPageLimitIncreaseUseCase(
        repository: repo,
        idGenerator: _SequenceIdGenerator(),
      );
      final results = await Future.wait([request('alice'), request('alice')]);
      expect(results.map((r) => r.id).toSet(), hasLength(1));
      expect(repo.limitRequests, hasLength(1));
    },
  );
  test('R03 concurrent creates cannot exceed quota three', () async {
    final repo = _MemoryIdentityWorkspaceRepository(
      _accessWithPageCount(2, userId: 'alice'),
    );
    final create = CreateProfessionalPageUseCase(
      repository: repo,
      idGenerator: _SequenceIdGenerator(),
    );
    await Future.wait([
      create(
        userId: 'alice',
        input: _creationInput('Third'),
      ).then<Object?>((p) => p, onError: (Object e) => e),
      create(
        userId: 'alice',
        input: _creationInput('Fourth'),
      ).then<Object?>((p) => p, onError: (Object e) => e),
    ]);
    expect(repo.accessSnapshot.pages, hasLength(3));
  });
  test('R04 foreign actor snapshot must not select a page', () async {
    final repo = _MemoryIdentityWorkspaceRepository(
      _accessWithPageCount(1, userId: 'alice'),
    );
    await expectLater(
      SelectWorkspaceUseCase(repo)(
        userId: 'bob',
        workspace: WorkspaceRef.page('page-0'),
      ),
      throwsA(isA<WorkspaceSelectionException>()),
    );
  });
  test(
    'R05 non-Admin with preview capability cannot enter Admin preview',
    () async {
      final repo = _MemoryIdentityWorkspaceRepository(
        _replaceAccess(_accessWithPageCount(0, userId: 'alice'), role: 'user'),
      );
      final controller = _controller(repo);
      addTearDown(controller.dispose);
      await controller.ensureLoaded('alice');
      expect(
        await controller.selectAdminPreview(AdminExperiencePreview.viewer),
        isFalse,
      );
    },
  );
  test('R06 capability revocation clears an open Admin preview', () async {
    final repo = _MemoryIdentityWorkspaceRepository(
      _accessWithPageCount(0, userId: 'alice'),
    );
    final controller = _controller(repo);
    addTearDown(controller.dispose);
    await controller.ensureLoaded('alice');
    await controller.selectAdminPreview(AdminExperiencePreview.viewer);
    repo.accessSnapshot = _replaceAccess(repo.accessSnapshot, capabilities: {});
    await controller.revalidateAccess();
    expect(controller.state.adminPreview, isNull);
  });
  test(
    'R07 switching account clears old access before asynchronous load',
    () async {
      final repo = _GatedRepository();
      final controller = _controller(repo);
      addTearDown(controller.dispose);
      await controller.ensureLoaded('alice');
      repo.blockBob = true;
      final loading = controller.ensureLoaded('bob');
      final oldSnapshot = controller.state.accessSnapshot;
      repo.bobGate.complete();
      await loading;
      expect(oldSnapshot, isNull);
    },
  );
  test(
    'R08 page-created notification remains addressed to its owner during account switch',
    () async {
      final repo = _GatedRepository();
      final sink = _MemoryNotificationSink();
      final controller = _controller(repo, sink: sink);
      addTearDown(controller.dispose);
      await controller.ensureLoaded('alice');
      final creating = controller.createProfessionalPage(
        displayName: 'Alice private name',
        kind: ManagedPageKind.company,
      );
      await repo.afterCreateLoadEntered.future;
      await controller.ensureLoaded('bob');
      repo.afterCreateLoadGate.complete();
      await creating;
      expect(
        sink.events
            .where((e) => e.audience == AppNotificationAudience.user)
            .map((e) => e.recipientUserId),
        everyElement('alice'),
      );
    },
  );
}

IdentityAccessSnapshot _replaceAccess(
  IdentityAccessSnapshot s, {
  String? role,
  Set<String>? capabilities,
}) => IdentityAccessSnapshot(
  userId: s.userId,
  globalRole: role ?? s.globalRole,
  creatorVerificationStatus: s.creatorVerificationStatus,
  globalCapabilities: capabilities ?? s.globalCapabilities,
  pages: s.pages,
  memberships: s.memberships,
  revision: s.revision + 1,
);

IdentityWorkspaceController _controller(
  IdentityWorkspaceRepository repo, {
  _MemoryNotificationSink? sink,
}) => IdentityWorkspaceController(
  loadIdentityWorkspaceUseCase: LoadIdentityWorkspaceUseCase(repo),
  selectWorkspaceUseCase: SelectWorkspaceUseCase(repo),
  createProfessionalPageUseCase: CreateProfessionalPageUseCase(
    repository: repo,
    idGenerator: _SequenceIdGenerator(),
  ),
  requestPageLimitIncreaseUseCase: RequestPageLimitIncreaseUseCase(
    repository: repo,
    idGenerator: _SequenceIdGenerator(),
  ),
  notificationSink: sink ?? _MemoryNotificationSink(),
  marketConfig: MarketConfig.riga,
  analyticsService: _NoopAnalyticsService(),
);

class _GatedRepository extends _MemoryIdentityWorkspaceRepository {
  _GatedRepository() : super(_accessWithPageCount(0, userId: 'alice'));
  bool blockBob = false;
  bool pageSelected = false;
  final bobGate = Completer<void>();
  final afterCreateLoadEntered = Completer<void>();
  final afterCreateLoadGate = Completer<void>();
  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async {
    if (userId == 'bob') {
      if (blockBob) await bobGate.future;
      return _accessWithPageCount(0, userId: 'bob');
    }
    if (pageSelected) {
      if (!afterCreateLoadEntered.isCompleted) {
        afterCreateLoadEntered.complete();
      }
      await afterCreateLoadGate.future;
    }
    return accessSnapshot;
  }

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async =>
      userId == 'bob' ? WorkspaceRef.personal('bob') : savedWorkspace;
  @override
  Future<void> saveActiveWorkspace(
    String userId,
    WorkspaceRef workspace,
  ) async {
    if (userId == 'alice') {
      savedWorkspace = workspace;
      pageSelected = workspace.isPage;
    }
  }
}

class _FailingOnceNotificationSink extends _MemoryNotificationSink {
  bool fail = true;
  @override
  Future<void> appendNotification(AppNotificationEvent event) async {
    if (fail && event.audience == AppNotificationAudience.moderators) {
      fail = false;
      throw Exception('notification_storage_unavailable');
    }
    await super.appendNotification(event);
  }
}
