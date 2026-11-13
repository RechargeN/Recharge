import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/identity/application/controllers/managed_page_profile_editor_controller.dart';
import 'package:recharge/features/identity/application/identity_workspace_providers.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_field_moderation_overlay.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/repositories/managed_page_field_moderation_repository.dart';
import 'package:recharge/features/identity/domain/usecases/submit_managed_page_field_edit_usecase.dart';
import 'package:recharge/features/identity/presentation/widgets/managed_page_profile_editor_card.dart';

void main() {
  const String ownerId = 'owner-1';

  ManagedPageEntity page() {
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
      supportedLocales: const <String>['en'],
      createdAtUtc: DateTime.utc(2026, 8, 16),
      revision: 3,
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

  ManagedPageProfileEditorController buildController(
    Set<String> capabilities,
  ) {
    final repository = _MemoryModerationRepository();
    return ManagedPageProfileEditorController(
      moderationRepository: repository,
      submitUseCase: SubmitManagedPageFieldEditUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(capabilities),
        ),
        moderationRepository: repository,
      ),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    ManagedPageProfileEditorController controller,
    Set<String> ownCapabilities,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          managedPageProfileEditorControllerProvider.overrideWith(
            (Ref ref) => controller,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManagedPageProfileEditorCard(
                page: page(),
                actingUserId: ownerId,
                ownCapabilities: ownCapabilities,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows Not set for every field before any edit', (
    WidgetTester tester,
  ) async {
    final capabilities = <String>{
      SubmitManagedPageFieldEditUseCase.pageManageCapability,
    };
    await pumpCard(tester, buildController(capabilities), capabilities);

    expect(find.text('Not set.'), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey<String>('edit-field-shortDescription')),
      findsOneWidget,
    );
  });

  testWidgets('a member without page.manage sees no edit affordance', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, buildController(<String>{}), <String>{});

    expect(
      find.byKey(const ValueKey<String>('edit-field-shortDescription')),
      findsNothing,
    );
  });

  testWidgets('editing the short description updates the displayed value', (
    WidgetTester tester,
  ) async {
    final capabilities = <String>{
      SubmitManagedPageFieldEditUseCase.pageManageCapability,
    };
    await pumpCard(tester, buildController(capabilities), capabilities);

    await tester.tap(
      find.byKey(const ValueKey<String>('edit-field-shortDescription')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('field-input-shortDescription')),
      'Bike tours across Riga',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('save-field-shortDescription')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bike tours across Riga'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
