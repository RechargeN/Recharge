import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_field_moderation_overlay.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/repositories/managed_page_field_moderation_repository.dart';
import 'package:recharge/features/identity/domain/usecases/submit_managed_page_field_edit_usecase.dart';

void main() {
  const String ownerId = 'owner-1';

  ManagedPageEntity page({int verificationRevision = 1}) {
    return ManagedPageEntity(
      id: 'page-1',
      ownerUserId: ownerId,
      kind: ManagedPageKind.company,
      displayName: 'Recharge Riga',
      avatar: '',
      verificationStatus: ManagedPageVerificationStatus.verified,
      lifecycle: ManagedPageLifecycle.active,
      marketId: 'riga',
      countryCode: 'LV',
      defaultLocale: 'en',
      timezone: 'Europe/Riga',
      defaultCurrency: 'EUR',
      supportedLocales: const <String>['en', 'lv'],
      createdAtUtc: DateTime.utc(2026, 8, 16),
      revision: 3,
      verificationRevision: verificationRevision,
    );
  }

  IdentityAccessSnapshot accessWithCapabilities(Set<String> capabilities) {
    return IdentityAccessSnapshot(
      userId: ownerId,
      globalRole: 'user',
      creatorVerificationStatus: CreatorVerificationStatus.verified,
      globalCapabilities: const <String>{},
      pages: const <ManagedPageEntity>[],
      memberships: <ManagedPageMembershipEntity>[
        ManagedPageMembershipEntity(
          pageId: 'page-1',
          userId: ownerId,
          relationship: ManagedPageRelationship.owner,
          status: ManagedPageMembershipStatus.active,
          capabilities: capabilities,
          revision: 1,
        ),
      ],
      revision: 1,
    );
  }

  SubmitManagedPageFieldEditUseCase useCase(
    _MemoryModerationRepository repository, {
    Set<String> capabilities = const <String>{
      SubmitManagedPageFieldEditUseCase.pageManageCapability,
    },
    DateTime Function()? utcNow,
  }) {
    return SubmitManagedPageFieldEditUseCase(
      workspaceRepository: _FakeWorkspaceRepository(
        accessWithCapabilities(capabilities),
      ),
      moderationRepository: repository,
      utcNow: utcNow,
    );
  }

  test('approves a short description edit for the page default locale', () async {
    final repository = _MemoryModerationRepository();
    final result = await useCase(
      repository,
      utcNow: () => DateTime.utc(2026, 1, 1),
    )(
      actingUserId: ownerId,
      page: page(),
      fieldKey: ManagedPageModeratedFieldKey.shortDescription,
      value: const ManagedPageLocalizedTextValue(<String, String>{
        'en': 'Bike tours across Riga',
      }),
      basedOnOverlayRevision: 0,
    );

    expect(
      (result.lastApprovedValue as ManagedPageLocalizedTextValue)
          .valuesByLocale['en'],
      'Bike tours across Riga',
    );
    expect(result.approvedForVerificationRevision, 1);
    expect(result.pendingSubmission, isNull);
    expect(result.revision, 1);
    expect(repository.saved, hasLength(1));
  });

  test('rejects an actor without page.manage', () async {
    final repository = _MemoryModerationRepository();

    await expectLater(
      () => useCase(repository, capabilities: const <String>{})(
        actingUserId: ownerId,
        page: page(),
        fieldKey: ManagedPageModeratedFieldKey.shortDescription,
        value: const ManagedPageLocalizedTextValue(<String, String>{
          'en': 'x',
        }),
        basedOnOverlayRevision: 0,
      ),
      throwsA(
        isA<SubmitManagedPageFieldEditException>().having(
          (SubmitManagedPageFieldEditException e) => e.code,
          'code',
          'actor_missing_page_manage_capability',
        ),
      ),
    );
  });

  test('rejects a value type mismatch for the field key', () async {
    final repository = _MemoryModerationRepository();

    await expectLater(
      () => useCase(repository)(
        actingUserId: ownerId,
        page: page(),
        fieldKey: ManagedPageModeratedFieldKey.customActivityLabel,
        value: const ManagedPageLocalizedTextValue(<String, String>{
          'en': 'wrong type',
        }),
        basedOnOverlayRevision: 0,
      ),
      throwsA(
        isA<SubmitManagedPageFieldEditException>().having(
          (SubmitManagedPageFieldEditException e) => e.code,
          'code',
          'field_value_type_mismatch',
        ),
      ),
    );
  });

  test('rejects a value for a locale the page does not support', () async {
    final repository = _MemoryModerationRepository();

    await expectLater(
      () => useCase(repository)(
        actingUserId: ownerId,
        page: page(),
        fieldKey: ManagedPageModeratedFieldKey.shortDescription,
        value: const ManagedPageLocalizedTextValue(<String, String>{
          'en': 'ok',
          'fr': 'not supported',
        }),
        basedOnOverlayRevision: 0,
      ),
      throwsA(
        isA<SubmitManagedPageFieldEditException>().having(
          (SubmitManagedPageFieldEditException e) => e.code,
          'code',
          'unsupported_locale',
        ),
      ),
    );
  });

  test('rejects a value missing the page default locale', () async {
    final repository = _MemoryModerationRepository();

    await expectLater(
      () => useCase(repository)(
        actingUserId: ownerId,
        page: page(),
        fieldKey: ManagedPageModeratedFieldKey.shortDescription,
        value: const ManagedPageLocalizedTextValue(<String, String>{
          'lv': 'only latvian',
        }),
        basedOnOverlayRevision: 0,
      ),
      throwsA(
        isA<SubmitManagedPageFieldEditException>().having(
          (SubmitManagedPageFieldEditException e) => e.code,
          'code',
          'default_locale_value_required',
        ),
      ),
    );
  });

  test('rejects a value that exceeds the bounded length limit', () async {
    final repository = _MemoryModerationRepository();

    await expectLater(
      () => useCase(repository)(
        actingUserId: ownerId,
        page: page(),
        fieldKey: ManagedPageModeratedFieldKey.shortDescription,
        value: ManagedPageLocalizedTextValue(<String, String>{
          'en': 'x' * (SubmitManagedPageFieldEditUseCase.maxShortTextLength + 1),
        }),
        basedOnOverlayRevision: 0,
      ),
      throwsA(isA<SubmitManagedPageFieldEditException>()),
    );
  });

  test('rejects a stale overlay revision', () async {
    final repository = _MemoryModerationRepository();
    await repository.saveOverlay(
      const ManagedPageFieldModerationOverlay(
        pageId: 'page-1',
        fieldKey: ManagedPageModeratedFieldKey.shortDescription,
        revision: 5,
        schemaVersion: 1,
      ),
    );

    await expectLater(
      () => useCase(repository)(
        actingUserId: ownerId,
        page: page(),
        fieldKey: ManagedPageModeratedFieldKey.shortDescription,
        value: const ManagedPageLocalizedTextValue(<String, String>{'en': 'x'}),
        basedOnOverlayRevision: 0,
      ),
      throwsA(
        isA<SubmitManagedPageFieldEditException>().having(
          (SubmitManagedPageFieldEditException e) => e.code,
          'code',
          'stale_overlay_revision',
        ),
      ),
    );
  });

  test('a clear request removes the approved value and sets clearedAtUtc', () async {
    final repository = _MemoryModerationRepository();
    final approved = await useCase(
      repository,
      utcNow: () => DateTime.utc(2026, 1, 1),
    )(
      actingUserId: ownerId,
      page: page(),
      fieldKey: ManagedPageModeratedFieldKey.customActivityLabel,
      value: const ManagedPageActivityLabelValue('Bike guide'),
      basedOnOverlayRevision: 0,
    );

    final cleared = await useCase(
      repository,
      utcNow: () => DateTime.utc(2026, 1, 2),
    )(
      actingUserId: ownerId,
      page: page(),
      fieldKey: ManagedPageModeratedFieldKey.customActivityLabel,
      value: null,
      basedOnOverlayRevision: approved.revision,
    );

    expect(cleared.clearedAtUtc, DateTime.utc(2026, 1, 2));
    expect(cleared.revision, 2);
    expect(
      cleared.effectiveValue(currentVerificationRevision: 1),
      isNull,
    );
  });

  test(
    'an approved value is scoped to the verification revision it was approved under',
    () async {
      final repository = _MemoryModerationRepository();
      final approved = await useCase(
        repository,
        utcNow: () => DateTime.utc(2026, 1, 1),
      )(
        actingUserId: ownerId,
        page: page(verificationRevision: 1),
        fieldKey: ManagedPageModeratedFieldKey.shortDescription,
        value: const ManagedPageLocalizedTextValue(<String, String>{
          'en': 'Bike tours',
        }),
        basedOnOverlayRevision: 0,
      );

      expect(
        approved.effectiveValue(currentVerificationRevision: 1),
        isNotNull,
      );
      expect(
        approved.effectiveValue(currentVerificationRevision: 2),
        isNull,
      );
    },
  );
}

class _FakeWorkspaceRepository implements IdentityWorkspaceRepository {
  _FakeWorkspaceRepository(this.snapshot);

  final IdentityAccessSnapshot snapshot;

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async {
    return snapshot;
  }

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

class _MemoryModerationRepository
    implements ManagedPageFieldModerationRepository {
  final List<ManagedPageFieldModerationOverlay> saved =
      <ManagedPageFieldModerationOverlay>[];

  @override
  Future<List<ManagedPageFieldModerationOverlay>> loadForPage(
    String pageId,
  ) async {
    return saved
        .where((ManagedPageFieldModerationOverlay item) => item.pageId == pageId)
        .toList(growable: false);
  }

  @override
  Future<void> saveOverlay(ManagedPageFieldModerationOverlay overlay) async {
    final int index = saved.indexWhere(
      (ManagedPageFieldModerationOverlay item) =>
          item.pageId == overlay.pageId && item.fieldKey == overlay.fieldKey,
    );
    if (index >= 0) {
      saved[index] = overlay;
    } else {
      saved.add(overlay);
    }
  }
}
