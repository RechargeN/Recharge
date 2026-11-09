import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:recharge/app/adapters/identity_publisher_access_check.dart';
import 'package:recharge/app/adapters/identity_route_authoring_policy.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/notifications/app_notification_sink.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/route_authoring_policy.dart';
import 'package:recharge/features/identity/application/controllers/identity_workspace_controller.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/select_workspace_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/create_professional_page_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/request_page_limit_increase_usecase.dart';
import 'package:recharge/features/identity/data/datasources/identity_workspace_local_datasource.dart';
import 'package:recharge/features/identity/data/datasources/mock_identity_fixture.dart';
import 'package:recharge/features/identity/data/repositories/identity_workspace_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('revocation during workspace switch is not lost while busy', () async {
    final repo = _DelayedGuardRepository(guardSnapshot());
    final controller = guardController(repo);
    addTearDown(controller.dispose);
    await controller.ensureLoaded('alice');
    repo.pauseSave = true;
    final switchResult = controller.selectWorkspace(
      WorkspaceRef.page('page-a'),
    );
    await repo.saveStarted.future;
    repo.change(
      guardSnapshot(membershipStatus: ManagedPageMembershipStatus.revoked),
    );
    final accessDuringRevoke = controller.state.accessSnapshot;
    repo.releaseSave.complete();
    await switchResult;
    await Future<void>.delayed(Duration.zero);
    expect(accessDuringRevoke, isNull);
    expect(controller.state.activeWorkspace, WorkspaceRef.personal('alice'));
    expect(controller.state.accessSnapshot?.canActivatePage('page-a'), isFalse);
  });

  test(
    'revocation during refresh never re-exposes an older snapshot',
    () async {
      final repo = _DelayedGuardRepository(guardSnapshot())
        ..workspace = WorkspaceRef.page('page-a');
      final controller = guardController(repo);
      addTearDown(controller.dispose);
      await controller.ensureLoaded('alice');
      repo.pauseLoad = true;
      final refresh = controller.revalidateAccess();
      await repo.loadStarted.future;
      var exposedRevokedAccess = false;
      controller.addListener(() {
        exposedRevokedAccess |=
            controller.state.accessSnapshot?.canActivatePage('page-a') ?? false;
      });
      repo.change(
        guardSnapshot(membershipStatus: ManagedPageMembershipStatus.revoked),
      );
      repo.releaseLoad.complete();
      await refresh;
      await Future<void>.delayed(Duration.zero);
      expect(exposedRevokedAccess, isFalse);
      expect(controller.state.activeWorkspace, WorkspaceRef.personal('alice'));
      expect(
        controller.state.accessSnapshot?.canActivatePage('page-a'),
        isFalse,
      );
    },
  );

  test(
    'new actor refresh does not join the previous actor pending read',
    () async {
      final repo = _DelayedGuardRepository(guardSnapshot());
      final controller = guardController(repo);
      addTearDown(controller.dispose);
      await controller.ensureLoaded('alice');
      repo.pauseLoad = true;
      final oldRefresh = controller.revalidateAccess();
      await repo.loadStarted.future;
      repo.snapshot = guardSnapshot(actor: 'bob');
      await controller.ensureLoaded('bob');
      repo.snapshot = guardSnapshot(
        actor: 'bob',
        membershipStatus: ManagedPageMembershipStatus.revoked,
      );
      var completed = false;
      final newRefresh = controller.revalidateAccess().then(
        (_) => completed = true,
      );
      await Future<void>.delayed(Duration.zero);
      final completedBeforeAlice = completed;
      repo.releaseLoad.complete();
      await oldRefresh;
      await newRefresh;
      expect(completedBeforeAlice, isTrue);
      expect(controller.state.userId, 'bob');
      expect(
        controller.state.accessSnapshot?.canActivatePage('page-a'),
        isFalse,
      );
    },
  );

  for (final role in ['user', 'creator', 'admin']) {
    for (final verified in [false, true]) {
      test(
        'Personal $role verified=$verified requires fresh eligibility and capability',
        () async {
          final repo = GuardRepository(
            guardSnapshot(role: role, verified: verified),
          );
          final check = IdentityPublisherAccessCheck(repo);
          const publisher = PublisherRef(type: PublisherType.user, id: 'alice');
          expect(
            await check.canPublishAs(
              actorUserId: 'alice',
              publisher: publisher,
              requiredCapabilities: {'submit.event'},
            ),
            verified,
          );
          repo.snapshot = guardSnapshot(
            role: role,
            verified: verified,
            capabilities: {},
          );
          expect(
            await check.canPublishAs(
              actorUserId: 'alice',
              publisher: publisher,
              requiredCapabilities: {'submit.event'},
            ),
            isFalse,
          );
        },
      );
    }
  }
  for (final status in ManagedPageMembershipStatus.values) {
    test('Page exact membership ${status.name}', () async {
      final check = IdentityPublisherAccessCheck(
        GuardRepository(guardSnapshot(membershipStatus: status)),
      );
      expect(
        await check.canPublishAs(
          actorUserId: 'alice',
          publisher: const PublisherRef(type: PublisherType.page, id: 'page-a'),
        ),
        status == ManagedPageMembershipStatus.active,
      );
      expect(
        await check.canPublishAs(
          actorUserId: 'alice',
          publisher: const PublisherRef(type: PublisherType.page, id: 'page-b'),
        ),
        isFalse,
      );
      expect(
        await check.canPublishAs(
          actorUserId: 'bob',
          publisher: const PublisherRef(type: PublisherType.page, id: 'page-a'),
        ),
        isFalse,
      );
    });
  }
  test(
    'Page capability, lifecycle and read failure deny without fallback',
    () async {
      final repo = GuardRepository(guardSnapshot(pageCapabilities: {}));
      final check = IdentityPublisherAccessCheck(repo);
      const publisher = PublisherRef(type: PublisherType.page, id: 'page-a');
      expect(
        await check.canPublishAs(actorUserId: 'alice', publisher: publisher),
        isFalse,
      );
      repo.snapshot = guardSnapshot(lifecycle: ManagedPageLifecycle.suspended);
      expect(
        await check.canPublishAs(actorUserId: 'alice', publisher: publisher),
        isFalse,
      );
      repo.failReads = true;
      expect(
        await check.canPublishAs(actorUserId: 'alice', publisher: publisher),
        isFalse,
      );
    },
  );
  test(
    'Route direct call ignores forged caller capabilities and checks actor',
    () async {
      final repo = GuardRepository(
        guardSnapshot(capabilities: {'admin.tools.view'}),
      );
      final policy = IdentityRouteAuthoringPolicy(repo);
      RouteAuthorizationRequest request(String actor) =>
          RouteAuthorizationRequest(
            actorId: actor,
            draftId: 'queue',
            operation: RouteAuthoringOperation.moderate,
            capabilities: {'moderate.route', 'admin.tools.view'},
          );
      expect((await policy.authorize(request('alice'))).allowed, isFalse);
      repo.snapshot = guardSnapshot();
      expect((await policy.authorize(request('alice'))).allowed, isTrue);
      expect((await policy.authorize(request('bob'))).allowed, isFalse);
      repo.snapshot = guardSnapshot(role: 'user');
      expect((await policy.authorize(request('alice'))).allowed, isFalse);
    },
  );
  test(
    'canonical repository rejects stale actor after session switch',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      String? actor = 'alice';
      final repo = IdentityWorkspaceRepositoryImpl(
        localDataSource: const IdentityWorkspaceLocalDataSource(
          FlutterSecureStorage(),
        ),
        mockFixture: const MockIdentityFixture(),
        currentActor: () async => actor,
      );
      expect((await repo.loadAccessSnapshot('alice')).userId, 'alice');
      actor = 'bob';
      await expectLater(repo.loadAccessSnapshot('alice'), throwsStateError);
      await expectLater(
        repo.saveActiveWorkspace('alice', WorkspaceRef.personal('alice')),
        throwsStateError,
      );
      actor = null;
      await expectLater(repo.loadAccessSnapshot('bob'), throwsStateError);
    },
  );
  test(
    'failed refresh clears usable access and returns safe personal state',
    () async {
      final repo = GuardRepository(guardSnapshot())
        ..workspace = WorkspaceRef.page('page-a');
      final controller = guardController(repo);
      addTearDown(controller.dispose);
      await controller.ensureLoaded('alice');
      repo.failReads = true;
      await controller.revalidateAccess();
      expect(controller.state.accessSnapshot, isNull);
      expect(controller.state.activeWorkspace, WorkspaceRef.personal('alice'));
      expect(controller.state.isLoaded, isFalse);
      expect(controller.state.message, isNotEmpty);
    },
  );
  test(
    'ownership quota counts revoked owned pages but not delegated pages',
    () {
      final owned = guardSnapshot(
        membershipStatus: ManagedPageMembershipStatus.revoked,
      );
      expect(owned.availablePages, isEmpty);
      expect(owned.ownedPages, hasLength(1));
      expect(
        guardSnapshot(relationship: ManagedPageRelationship.manager).ownedPages,
        isEmpty,
      );
    },
  );
}

IdentityAccessSnapshot guardSnapshot({
  String actor = 'alice',
  String role = 'admin',
  bool verified = true,
  Set<String> capabilities = const {
    'page.create',
    'submit.event',
    'admin.tools.view',
    'admin.experience.preview',
    'moderate.route',
  },
  Set<String> pageCapabilities = const {
    'page.manage',
    'page.team.manage',
    'page.content.create',
    'page.content.submit',
  },
  ManagedPageMembershipStatus membershipStatus =
      ManagedPageMembershipStatus.active,
  ManagedPageLifecycle lifecycle = ManagedPageLifecycle.active,
  ManagedPageRelationship relationship = ManagedPageRelationship.owner,
}) => IdentityAccessSnapshot(
  userId: actor,
  globalRole: role,
  creatorVerificationStatus: verified
      ? CreatorVerificationStatus.verified
      : CreatorVerificationStatus.revoked,
  globalCapabilities: capabilities,
  pages: [
    ManagedPageEntity(
      id: 'page-a',
      ownerUserId: actor,
      kind: ManagedPageKind.company,
      displayName: 'Private Page A',
      avatar: '',
      verificationStatus: ManagedPageVerificationStatus.pending,
      lifecycle: lifecycle,
      marketId: 'riga',
      countryCode: 'LV',
      defaultLocale: 'en',
      timezone: 'Europe/Riga',
      defaultCurrency: 'EUR',
      supportedLocales: const ['en'],
      createdAtUtc: DateTime.utc(2026),
      revision: 1,
    ),
  ],
  memberships: [
    ManagedPageMembershipEntity(
      pageId: 'page-a',
      userId: actor,
      relationship: relationship,
      status: membershipStatus,
      capabilities: pageCapabilities,
      revision: 1,
    ),
  ],
  revision: 1,
);

class GuardRepository implements IdentityWorkspaceRepository {
  GuardRepository(this.snapshot);
  IdentityAccessSnapshot snapshot;
  WorkspaceRef? workspace;
  bool failReads = false;
  void change(IdentityAccessSnapshot value) {
    snapshot = value;
    IdentityWorkspaceRepository.notifyAccessChanged(value.userId);
  }

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async {
    if (failReads) throw StateError('unavailable');
    return snapshot;
  }

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async => workspace;
  @override
  Future<void> saveActiveWorkspace(String userId, WorkspaceRef value) async {
    workspace = value;
  }

  @override
  Future<void> saveCreatedPage({
    required String userId,
    required ManagedPageEntity page,
    required ManagedPageMembershipEntity membership,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PageLimitIncreaseRequestEntity?> loadPendingPageLimitRequest(
    String userId,
  ) async => null;
  @override
  Future<void> savePageLimitRequest(
    PageLimitIncreaseRequestEntity request,
  ) async {
    throw UnimplementedError();
  }
}

IdentityWorkspaceController guardController(IdentityWorkspaceRepository repo) =>
    IdentityWorkspaceController(
      loadIdentityWorkspaceUseCase: LoadIdentityWorkspaceUseCase(repo),
      selectWorkspaceUseCase: SelectWorkspaceUseCase(repo),
      createProfessionalPageUseCase: CreateProfessionalPageUseCase(
        repository: repo,
        idGenerator: GuardIds(),
      ),
      requestPageLimitIncreaseUseCase: RequestPageLimitIncreaseUseCase(
        repository: repo,
        idGenerator: GuardIds(),
      ),
      notificationSink: GuardSink(),
      marketConfig: MarketConfig.riga,
      analyticsService: GuardAnalytics(),
    );

class GuardIds implements IdGenerator {
  @override
  String generate() => '00000000-0000-4000-8000-000000000001';
}

class GuardSink implements AppNotificationSink {
  @override
  Future<void> appendNotification(AppNotificationEvent event) async {}
}

class GuardAnalytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _DelayedGuardRepository extends GuardRepository {
  _DelayedGuardRepository(super.snapshot);
  bool pauseSave = false;
  bool pauseLoad = false;
  final saveStarted = Completer<void>();
  final releaseSave = Completer<void>();
  final loadStarted = Completer<void>();
  final releaseLoad = Completer<void>();
  @override
  Future<void> saveActiveWorkspace(String userId, WorkspaceRef value) async {
    if (pauseSave) {
      pauseSave = false;
      saveStarted.complete();
      await releaseSave.future;
    }
    await super.saveActiveWorkspace(userId, value);
  }

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async {
    if (pauseLoad) {
      pauseLoad = false;
      loadStarted.complete();
      await releaseLoad.future;
    }
    return super.loadActiveWorkspace(userId);
  }
}
