import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/identity/application/controllers/public_professional_page_controller.dart';
import 'package:recharge/features/identity/application/state/public_professional_page_state.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_field_moderation_overlay.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/public_professional_page.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/repositories/public_professional_page_repository.dart';
import 'package:recharge/features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/resolve_public_professional_page_usecase.dart';

void main() {
  group('public Professional Page resolver', () {
    test('only verified and active resolves publicly', () async {
      for (final ManagedPageVerificationStatus verification
          in ManagedPageVerificationStatus.values) {
        for (final ManagedPageLifecycle lifecycle
            in ManagedPageLifecycle.values) {
          final ManagedPageEntity page = _page(
            verification: verification,
            lifecycle: lifecycle,
          );
          final ResolvePublicProfessionalPageUseCase resolver = _resolver(page);

          final PublicProfessionalPageResolution result = await resolver(
            lookup: PublicProfessionalPageLookup.id,
            reference: page.id,
            requestedLocale: 'en',
          );

          expect(
            result.isPublicPage,
            verification == ManagedPageVerificationStatus.verified &&
                lifecycle == ManagedPageLifecycle.active,
            reason: '${verification.name}/${lifecycle.name}',
          );
        }
      }
    });

    test('missing and hidden pages return the same result type', () async {
      final ManagedPageEntity hidden = _page(
        verification: ManagedPageVerificationStatus.pending,
      );
      final ResolvePublicProfessionalPageUseCase resolver = _resolver(hidden);

      final PublicProfessionalPageResolution hiddenResult = await resolver(
        lookup: PublicProfessionalPageLookup.id,
        reference: hidden.id,
        requestedLocale: 'en',
      );
      final PublicProfessionalPageResolution missingResult = await resolver(
        lookup: PublicProfessionalPageLookup.id,
        reference: 'missing-page',
        requestedLocale: 'en',
      );

      expect(hiddenResult.type, PublicProfessionalPageResolutionType.notFound);
      expect(missingResult.type, hiddenResult.type);
      expect(hiddenResult.projection, isNull);
      expect(missingResult.projection, isNull);
    });

    test('id and slug resolve the same locale-scoped projection', () async {
      final ManagedPageEntity page = _page();
      final ResolvePublicProfessionalPageUseCase resolver = _resolver(page);

      final PublicProfessionalPageResolution byId = await resolver(
        lookup: PublicProfessionalPageLookup.id,
        reference: page.id,
        requestedLocale: 'en',
      );
      final PublicProfessionalPageResolution bySlug = await resolver(
        lookup: PublicProfessionalPageLookup.slug,
        reference: page.slug,
        requestedLocale: 'en',
      );

      expect(byId.projection!.pageId, bySlug.projection!.pageId);
      expect(
        byId.projection!.publicRevision,
        bySlug.projection!.publicRevision,
      );
      expect(byId.projection!.contentSummary.timelessCount, 0);
    });

    test(
      'pending page can be projected only through explicit preview',
      () async {
        final ManagedPageEntity page = _page(
          verification: ManagedPageVerificationStatus.pending,
        );
        final ResolvePublicProfessionalPageUseCase resolver = _resolver(page);

        final PublicManagedPageProjection preview = await resolver.buildPreview(
          page: page,
          requestedLocale: 'en',
        );

        expect(preview.pageId, page.id);
        expect(preview.verificationBadge, isFalse);
        expect(preview.contentSummary.publishedCount, 0);
      },
    );

    test('blank or malformed lookup fails closed', () async {
      final ManagedPageEntity page = _page();
      final ResolvePublicProfessionalPageUseCase resolver = _resolver(page);

      final PublicProfessionalPageResolution blank = await resolver(
        lookup: PublicProfessionalPageLookup.slug,
        reference: '   ',
        requestedLocale: 'en',
      );
      final PublicProfessionalPageResolution missingLocale = await resolver(
        lookup: PublicProfessionalPageLookup.id,
        reference: page.id,
        requestedLocale: '   ',
      );

      expect(blank.type, PublicProfessionalPageResolutionType.notFound);
      expect(missingLocale.type, PublicProfessionalPageResolutionType.notFound);
    });
  });

  group('ManagedPageFieldModerationOverlay', () {
    test('serves only compatible value approved for current verification', () {
      final overlay = ManagedPageFieldModerationOverlay(
        pageId: 'page-1',
        fieldKey: ManagedPageModeratedFieldKey.displayName,
        lastApprovedValue: const ManagedPageLocalizedTextValue(<String, String>{
          'en': 'Approved',
        }),
        lastApprovedAtUtc: DateTime.utc(2026, 8, 16),
        approvedForVerificationRevision: 4,
        revision: 2,
        schemaVersion: 1,
      );

      expect(
        overlay.effectiveValue(currentVerificationRevision: 4),
        isA<ManagedPageLocalizedTextValue>(),
      );
      expect(overlay.effectiveValue(currentVerificationRevision: 5), isNull);
    });

    test('unknown key/value pairing and approved clear fail closed', () {
      final wrongType = ManagedPageFieldModerationOverlay(
        pageId: 'page-1',
        fieldKey: ManagedPageModeratedFieldKey.avatarMediaRef,
        lastApprovedValue: const ManagedPageShortTextValue('not-media'),
        approvedForVerificationRevision: 1,
        revision: 1,
        schemaVersion: 1,
      );
      final cleared = ManagedPageFieldModerationOverlay(
        pageId: 'page-1',
        fieldKey: ManagedPageModeratedFieldKey.avatarMediaRef,
        lastApprovedValue: const ManagedPageMediaValue('media-1'),
        approvedForVerificationRevision: 1,
        clearedAtUtc: DateTime.utc(2026, 8, 16),
        revision: 2,
        schemaVersion: 1,
      );

      expect(wrongType.effectiveValue(currentVerificationRevision: 1), isNull);
      expect(cleared.effectiveValue(currentVerificationRevision: 1), isNull);
    });
  });

  group('owner preview authorization', () {
    test('active exact-page member can preview a pending page', () async {
      final ManagedPageEntity page = _page(
        verification: ManagedPageVerificationStatus.pending,
      );
      final _MemoryIdentityRepository identity = _MemoryIdentityRepository(
        _access(page),
      );
      final controller = PublicProfessionalPageController(
        resolvePage: _resolver(page),
        loadIdentityWorkspace: LoadIdentityWorkspaceUseCase(identity),
      );

      await controller.loadPreview(
        userId: 'owner-1',
        pageId: page.id,
        requestedLocale: 'en',
      );

      expect(controller.state.status, PublicProfessionalPageStatus.ready);
      expect(controller.state.viewerContext!.isPreview, isTrue);
      expect(controller.state.viewerContext!.canEditPage, isTrue);
      expect(controller.state.projection!.verificationBadge, isFalse);
    });

    test('membership on page A cannot preview page B', () async {
      final ManagedPageEntity pageA = _page(
        verification: ManagedPageVerificationStatus.pending,
      );
      final _MemoryIdentityRepository identity = _MemoryIdentityRepository(
        _access(pageA),
      );
      final controller = PublicProfessionalPageController(
        resolvePage: _resolver(pageA),
        loadIdentityWorkspace: LoadIdentityWorkspaceUseCase(identity),
      );

      await controller.loadPreview(
        userId: 'owner-1',
        pageId: 'page-b',
        requestedLocale: 'en',
      );

      expect(controller.state.status, PublicProfessionalPageStatus.notFound);
      expect(controller.state.projection, isNull);
    });

    test(
      'team membership changes affordances but not the public projection',
      () async {
        final ManagedPageEntity page = _page();
        final memberController = PublicProfessionalPageController(
          resolvePage: _resolver(page),
          loadIdentityWorkspace: LoadIdentityWorkspaceUseCase(
            _MemoryIdentityRepository(_access(page)),
          ),
        );
        final viewerController = PublicProfessionalPageController(
          resolvePage: _resolver(page),
          loadIdentityWorkspace: LoadIdentityWorkspaceUseCase(
            _MemoryIdentityRepository(_accessWithoutMembership(page)),
          ),
        );

        await memberController.loadPublic(
          userId: 'owner-1',
          lookup: PublicProfessionalPageLookup.slug,
          reference: page.slug,
          requestedLocale: 'en',
        );
        await viewerController.loadPublic(
          userId: 'viewer-2',
          lookup: PublicProfessionalPageLookup.slug,
          reference: page.slug,
          requestedLocale: 'en',
        );

        expect(
          memberController.state.projection!.publicRevision,
          viewerController.state.projection!.publicRevision,
        );
        expect(memberController.state.projection!.pageId, page.id);
        expect(viewerController.state.projection!.pageId, page.id);
        expect(memberController.state.viewerContext!.canEditPage, isTrue);
        expect(viewerController.state.viewerContext!.canEditPage, isFalse);
      },
    );
  });
}

ResolvePublicProfessionalPageUseCase _resolver(ManagedPageEntity page) {
  return ResolvePublicProfessionalPageUseCase(
    repository: _MemoryPublicPageRepository(<ManagedPageEntity>[page]),
    contentRepository: const _EmptyContentRepository(),
  );
}

ManagedPageEntity _page({
  ManagedPageVerificationStatus verification =
      ManagedPageVerificationStatus.verified,
  ManagedPageLifecycle lifecycle = ManagedPageLifecycle.active,
}) {
  return ManagedPageEntity(
    id: 'page-verified-1',
    ownerUserId: 'owner-1',
    kind: ManagedPageKind.organization,
    displayName: 'Recharge Riga',
    slug: 'recharge-riga',
    avatar: '',
    verificationStatus: verification,
    lifecycle: lifecycle,
    marketId: 'riga',
    countryCode: 'LV',
    defaultLocale: 'en',
    timezone: 'Europe/Riga',
    defaultCurrency: 'EUR',
    supportedLocales: const <String>['en', 'lv', 'ru'],
    createdAtUtc: DateTime.utc(2026, 8, 16),
    revision: 3,
  );
}

class _MemoryPublicPageRepository implements PublicProfessionalPageRepository {
  const _MemoryPublicPageRepository(this.pages);

  final List<ManagedPageEntity> pages;

  @override
  Future<ManagedPageEntity?> findById(String pageId) async {
    for (final ManagedPageEntity page in pages) {
      if (page.id == pageId) return page;
    }
    return null;
  }

  @override
  Future<ManagedPageEntity?> findBySlug(String slug) async {
    for (final ManagedPageEntity page in pages) {
      if (page.slug == slug) return page;
    }
    return null;
  }
}

class _EmptyContentRepository implements PublicPageContentProjectionRepository {
  const _EmptyContentRepository();

  @override
  Future<PublicPageContentSummary> loadSummaryForPage(String pageId) async {
    return const PublicPageContentSummary.empty();
  }
}

IdentityAccessSnapshot _access(ManagedPageEntity page) {
  return IdentityAccessSnapshot(
    userId: 'owner-1',
    globalRole: 'creator',
    creatorVerificationStatus: CreatorVerificationStatus.verified,
    globalCapabilities: const <String>{'page.create'},
    pages: <ManagedPageEntity>[page],
    memberships: <ManagedPageMembershipEntity>[
      ManagedPageMembershipEntity(
        pageId: page.id,
        userId: 'owner-1',
        relationship: ManagedPageRelationship.owner,
        status: ManagedPageMembershipStatus.active,
        capabilities: const <String>{'page.manage'},
        revision: 1,
      ),
    ],
    revision: 1,
  );
}

IdentityAccessSnapshot _accessWithoutMembership(ManagedPageEntity page) {
  return IdentityAccessSnapshot(
    userId: 'viewer-2',
    globalRole: 'user',
    creatorVerificationStatus: CreatorVerificationStatus.notStarted,
    globalCapabilities: const <String>{},
    pages: <ManagedPageEntity>[page],
    memberships: const <ManagedPageMembershipEntity>[],
    revision: 1,
  );
}

class _MemoryIdentityRepository implements IdentityWorkspaceRepository {
  _MemoryIdentityRepository(this.access);

  final IdentityAccessSnapshot access;
  WorkspaceRef? workspace;

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async =>
      access;

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async => workspace;

  @override
  Future<void> saveActiveWorkspace(
    String userId,
    WorkspaceRef workspace,
  ) async {
    this.workspace = workspace;
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
