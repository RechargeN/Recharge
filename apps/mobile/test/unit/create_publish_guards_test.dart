import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/identity_publisher_access_check.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/state/create_state.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/draft_publisher.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/publisher_access_check.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';

import '../support/event_create_test_support.dart';

const PublisherRef _page = PublisherRef(type: PublisherType.page, id: 'page-1');

void main() {
  group('publish-time publisher guard (IDP-05A)', () {
    test('revoked Page access denies publish and keeps the draft', () async {
      final _Repo repo = _Repo();
      final CreateController controller = _controller(
        repo,
        access: _FakeAccess(allowed: false),
      );
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'u@example.com',
        organizerName: 'U',
        activePublisherRef: _page,
      );
      controller.setObjectType(CreateObjectType.place);

      final bool published = await controller.publishDraft();

      expect(published, isFalse);
      expect(repo.publishCalls, 0);
      expect(controller.state.publishedDraft, isNull);
      expect(controller.state.message, contains('Черновик сохранён'));
      // Draft untouched: owner is never silently rewritten to the user.
      expect(controller.state.draft.effectivePublisher, _page);
    });

    test(
      'Page publisher without a composed access check fails closed',
      () async {
        final _Repo repo = _Repo();
        final CreateController controller = _controller(repo);
        addTearDown(controller.dispose);
        await controller.ensureLoaded(
          userId: 'user-1',
          organizerEmail: 'u@example.com',
          organizerName: 'U',
          activePublisherRef: _page,
        );
        controller.setObjectType(CreateObjectType.activity);

        expect(await controller.publishDraft(), isFalse);
        expect(repo.publishCalls, 0);
      },
    );

    test('types without a typed publisher resolve to the personal user', () {
      final CreateDraftEntity draft = CreateDraftEntity.defaults(
        organizerId: 'user-1',
        organizerEmail: 'u@example.com',
        organizerName: 'U',
      ).copyWith(objectType: CreateObjectType.classWorkshop);
      expect(
        draft.effectivePublisher,
        const PublisherRef(type: PublisherType.user, id: 'user-1'),
      );
    });

    test('a second publishDraft during a running publish is ignored', () async {
      final Completer<void> gate = Completer<void>();
      final _Repo repo = _Repo(publishGate: gate.future);
      final CreateController controller = _controller(repo);
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'u@example.com',
        organizerName: 'U',
      );
      controller.setObjectType(CreateObjectType.classWorkshop);
      controller.updateTitle('Pottery');
      controller.updateMainCategory('outdoor_nature_walking');
      controller.updateCity('Riga');
      controller.updateCoverImage('cover.jpg');
      controller.updateStartDateTime(
        DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
      );

      final Future<bool> first = controller.publishDraft();
      final bool second = await controller.publishDraft();
      gate.complete();

      expect(second, isFalse);
      expect(await first, isTrue);
      expect(repo.publishCalls, 1);
    });
  });

  group('failure and restart recovery', () {
    Future<CreateController> readyClassWorkshop(_Repo repo) async {
      final CreateController controller = _controller(repo);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'u@example.com',
        organizerName: 'U',
      );
      controller.setObjectType(CreateObjectType.classWorkshop);
      controller.updateTitle('Pottery');
      controller.updateMainCategory('outdoor_nature_walking');
      controller.updateCity('Riga');
      controller.updateCoverImage('cover.jpg');
      controller.updateStartDateTime(
        DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
      );
      return controller;
    }

    test(
      'storage failure keeps the draft and a retry publishes once',
      () async {
        final _Repo repo = _Repo(failFirstPublish: true);
        final CreateController controller = await readyClassWorkshop(repo);
        addTearDown(controller.dispose);

        expect(await controller.publishDraft(), isFalse);
        expect(controller.state.status, CreateStatus.ready);
        expect(controller.state.draft.title, 'Pottery');
        expect(controller.state.message, contains('Черновик сохранён'));
        expect(repo.stored?.title, 'Pottery');

        expect(await controller.publishDraft(), isTrue);
        expect(await controller.publishDraft(), isTrue);
        expect(
          controller.state.publishedDraft?.publishStatus,
          PublishStatus.pendingReview,
        );
        expect(repo.stored?.publishStatus, PublishStatus.pendingReview);
      },
    );

    test('draft survives an app restart before publish', () async {
      final _Repo repo = _Repo();
      final CreateController first = await readyClassWorkshop(repo);
      await first.saveDraft();
      first.dispose();

      final CreateController second = _controller(repo);
      addTearDown(second.dispose);
      await second.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'u@example.com',
        organizerName: 'U',
      );

      expect(second.state.draft.title, 'Pottery');
      expect(second.state.draft.objectType, CreateObjectType.classWorkshop);
    });
  });

  group('IdentityPublisherAccessCheck', () {
    test(
      'active member with submit capability may publish as the Page',
      () async {
        final IdentityPublisherAccessCheck check = IdentityPublisherAccessCheck(
          _IdentityRepo(_snapshot()),
        );
        expect(
          await check.canPublishAs(actorUserId: 'user-1', publisher: _page),
          isTrue,
        );
      },
    );

    test(
      'revoked membership, missing capability and other pages are denied',
      () async {
        Future<bool> allowed(
          IdentityAccessSnapshot snapshot,
          PublisherRef ref,
        ) {
          return IdentityPublisherAccessCheck(
            _IdentityRepo(snapshot),
          ).canPublishAs(actorUserId: 'user-1', publisher: ref);
        }

        expect(
          await allowed(
            _snapshot(status: ManagedPageMembershipStatus.revoked),
            _page,
          ),
          isFalse,
        );
        expect(
          await allowed(_snapshot(capabilities: const <String>{}), _page),
          isFalse,
        );
        expect(
          await allowed(
            _snapshot(),
            const PublisherRef(type: PublisherType.page, id: 'page-2'),
          ),
          isFalse,
        );
        expect(
          await allowed(
            _snapshot(creator: CreatorVerificationStatus.revoked),
            _page,
          ),
          isFalse,
        );
        expect(
          await allowed(
            _snapshot(lifecycle: ManagedPageLifecycle.suspended),
            _page,
          ),
          isFalse,
        );
      },
    );

    test('personal publisher must be the acting user', () async {
      final IdentityPublisherAccessCheck check = IdentityPublisherAccessCheck(
        _IdentityRepo(_snapshot()),
      );
      expect(
        await check.canPublishAs(
          actorUserId: 'user-1',
          publisher: const PublisherRef(type: PublisherType.user, id: 'user-1'),
        ),
        isTrue,
      );
      expect(
        await check.canPublishAs(
          actorUserId: 'user-1',
          publisher: const PublisherRef(type: PublisherType.user, id: 'user-2'),
        ),
        isFalse,
      );
    });
  });
}

IdentityAccessSnapshot _snapshot({
  ManagedPageMembershipStatus status = ManagedPageMembershipStatus.active,
  Set<String> capabilities = const <String>{'page.content.submit'},
  CreatorVerificationStatus creator = CreatorVerificationStatus.verified,
  ManagedPageLifecycle lifecycle = ManagedPageLifecycle.active,
}) {
  return IdentityAccessSnapshot(
    userId: 'user-1',
    globalRole: 'user',
    creatorVerificationStatus: creator,
    globalCapabilities: const <String>{},
    pages: <ManagedPageEntity>[
      ManagedPageEntity(
        id: 'page-1',
        ownerUserId: 'user-1',
        kind: ManagedPageKind.company,
        displayName: 'Page',
        avatar: '',
        verificationStatus: ManagedPageVerificationStatus.pending,
        lifecycle: lifecycle,
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
        capabilities: capabilities,
        revision: 1,
      ),
    ],
    revision: 1,
  );
}

CreateController _controller(_Repo repo, {PublisherAccessCheck? access}) {
  return CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(repo),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(repo),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(repo),
    analyticsService: _NoopAnalytics(),
    eventCreateCoordinator: createTestEventCoordinator(),
    publisherAccessCheck: access,
    runtimeDefaults: const CreateRuntimeDefaults(
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    ),
  );
}

class _FakeAccess implements PublisherAccessCheck {
  _FakeAccess({required this.allowed});

  final bool allowed;

  @override
  Future<bool> canPublishAs({
    required String actorUserId,
    required PublisherRef publisher,
  }) async => allowed;
}

class _NoopAnalytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _Repo implements CreateRepository {
  _Repo({this.publishGate, this.failFirstPublish = false});

  final Future<void>? publishGate;
  bool failFirstPublish;
  CreateDraftEntity? stored;
  int publishCalls = 0;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    stored = draft;
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    publishCalls += 1;
    await publishGate;
    if (failFirstPublish) {
      failFirstPublish = false;
      throw StateError('storage unavailable');
    }
    final CreateDraftEntity? existing = stored;
    if (existing != null &&
        existing.publishStatus == PublishStatus.pendingReview) {
      return existing;
    }
    final CreateDraftEntity published = draft.copyWith(
      publishStatus: PublishStatus.pendingReview,
    );
    stored = published;
    return published;
  }
}

class _IdentityRepo implements IdentityWorkspaceRepository {
  _IdentityRepo(this.snapshot);

  final IdentityAccessSnapshot snapshot;

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async =>
      snapshot;

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async => null;

  @override
  Future<void> saveActiveWorkspace(
    String userId,
    WorkspaceRef workspace,
  ) async {}

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
