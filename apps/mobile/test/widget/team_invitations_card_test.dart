import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/identity/application/controllers/team_invitation_controller.dart';
import 'package:recharge/features/identity/application/identity_workspace_providers.dart';
import 'package:recharge/features/identity/domain/entities/identity_access_snapshot.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_entity.dart';
import 'package:recharge/features/identity/domain/entities/managed_page_membership_entity.dart';
import 'package:recharge/features/identity/domain/entities/page_limit_increase_request_entity.dart';
import 'package:recharge/features/identity/domain/entities/team_invitation_entity.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import 'package:recharge/features/identity/domain/repositories/identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/repositories/team_invitation_repository.dart';
import 'package:recharge/features/identity/domain/usecases/revoke_team_invitation_usecase.dart';
import 'package:recharge/features/identity/domain/usecases/send_team_invitation_usecase.dart';
import 'package:recharge/features/identity/presentation/widgets/team_invitations_card.dart';

void main() {
  const String pageId = 'page-1';
  const String ownerId = 'owner-1';

  IdentityAccessSnapshot accessWithCapabilities(Set<String> capabilities) {
    return IdentityAccessSnapshot(
      userId: ownerId,
      globalRole: 'user',
      creatorVerificationStatus: CreatorVerificationStatus.verified,
      globalCapabilities: const <String>{},
      pages: const <ManagedPageEntity>[],
      memberships: <ManagedPageMembershipEntity>[
        ManagedPageMembershipEntity(
          pageId: pageId,
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

  TeamInvitationController buildController(Set<String> capabilities) {
    final repository = _MemoryTeamInvitationRepository();
    final workspaceRepository = _FakeWorkspaceRepository(
      accessWithCapabilities(capabilities),
    );
    return TeamInvitationController(
      invitationRepository: repository,
      sendUseCase: SendTeamInvitationUseCase(
        workspaceRepository: workspaceRepository,
        invitationRepository: repository,
        idGenerator: _SequenceIdGenerator(),
      ),
      revokeUseCase: RevokeTeamInvitationUseCase(
        workspaceRepository: workspaceRepository,
        invitationRepository: repository,
      ),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    TeamInvitationController controller,
    Set<String> ownCapabilities,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          teamInvitationControllerProvider.overrideWith((Ref ref) => controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeamInvitationsCard(
                pageId: pageId,
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

  testWidgets('a member without team.manage sees a denial, not the form', (
    WidgetTester tester,
  ) async {
    final controller = buildController(<String>{'page.content.create'});
    await pumpCard(tester, controller, <String>{'page.content.create'});

    expect(
      find.text('You do not have permission to manage the team.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('send-team-invitation')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state renders for an authorized member', (
    WidgetTester tester,
  ) async {
    final capabilities = <String>{
      SendTeamInvitationUseCase.teamManageCapability,
    };
    final controller = buildController(capabilities);
    await pumpCard(tester, controller, capabilities);

    expect(
      find.text('No invitations sent from this page yet.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('send-team-invitation')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('send then revoke updates the list end to end', (
    WidgetTester tester,
  ) async {
    final capabilities = <String>{
      SendTeamInvitationUseCase.teamManageCapability,
    };
    final controller = buildController(capabilities);
    await pumpCard(tester, controller, capabilities);

    await tester.tap(
      find.byKey(const ValueKey<String>('send-team-invitation')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('team-invitation-target-value')),
      'colleague@example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('submit-team-invitation')),
    );
    await tester.pumpAndSettle();

    expect(find.text('colleague@example.com'), findsOneWidget);
    expect(find.text('editor · Pending'), findsOneWidget);
    expect(find.text('Revoke'), findsOneWidget);

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();

    expect(find.text('editor · Revoked'), findsOneWidget);
    expect(find.text('Revoke'), findsNothing);
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

class _MemoryTeamInvitationRepository implements TeamInvitationRepository {
  final List<TeamInvitationEntity> saved = <TeamInvitationEntity>[];

  @override
  Future<List<TeamInvitationEntity>> loadForPage(String pageId) async {
    return saved
        .where((TeamInvitationEntity item) => item.pageId == pageId)
        .toList(growable: false);
  }

  @override
  Future<void> saveInvitation(TeamInvitationEntity invitation) async {
    final int index = saved.indexWhere(
      (TeamInvitationEntity item) => item.id == invitation.id,
    );
    if (index >= 0) {
      saved[index] = invitation;
    } else {
      saved.add(invitation);
    }
  }
}

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'invitation-${_next++}';
}
