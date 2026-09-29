import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
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

  group('SendTeamInvitationUseCase', () {
    test('sends a new invitation for an authorized inviter', () async {
      final repository = _MemoryTeamInvitationRepository();
      final useCase = SendTeamInvitationUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(<String>{
            SendTeamInvitationUseCase.teamManageCapability,
            'page.content.create',
          }),
        ),
        invitationRepository: repository,
        idGenerator: _SequenceIdGenerator(),
        utcNow: () => DateTime.utc(2026, 1, 1),
      );

      final invitation = await useCase(
        actingUserId: ownerId,
        pageId: pageId,
        target: const TeamInvitationTarget(
          type: TeamInvitationTargetType.email,
          value: 'colleague@example.com',
        ),
        proposedRelationship: ManagedPageRelationship.editor,
        proposedCapabilities: const <String>{'page.content.create'},
      );

      expect(invitation.status, TeamInvitationStatus.pending);
      expect(invitation.resendCount, 0);
      expect(
        invitation.expiresAtUtc,
        DateTime.utc(2026, 1, 1).add(TeamInvitationEntity.defaultExpiry),
      );
      expect(repository.saved, hasLength(1));
    });

    test('rejects a delegation the inviter does not themselves hold', () async {
      final useCase = SendTeamInvitationUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(<String>{
            SendTeamInvitationUseCase.teamManageCapability,
          }),
        ),
        invitationRepository: _MemoryTeamInvitationRepository(),
        idGenerator: _SequenceIdGenerator(),
      );

      await expectLater(
        () => useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: const TeamInvitationTarget(
            type: TeamInvitationTargetType.email,
            value: 'colleague@example.com',
          ),
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{'page.finance.manage'},
        ),
        throwsA(
          isA<SendTeamInvitationException>().having(
            (SendTeamInvitationException error) => error.code,
            'code',
            'cannot_delegate_capability_not_held',
          ),
        ),
      );
    });

    test('rejects an inviter without team-manage capability', () async {
      final useCase = SendTeamInvitationUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(<String>{'page.content.create'}),
        ),
        invitationRepository: _MemoryTeamInvitationRepository(),
        idGenerator: _SequenceIdGenerator(),
      );

      await expectLater(
        () => useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: const TeamInvitationTarget(
            type: TeamInvitationTargetType.userId,
            value: 'user-2',
          ),
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        ),
        throwsA(
          isA<SendTeamInvitationException>().having(
            (SendTeamInvitationException error) => error.code,
            'code',
            'inviter_missing_team_manage_capability',
          ),
        ),
      );
    });

    test('never invites into the owner relationship', () async {
      final useCase = SendTeamInvitationUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(<String>{
            SendTeamInvitationUseCase.teamManageCapability,
          }),
        ),
        invitationRepository: _MemoryTeamInvitationRepository(),
        idGenerator: _SequenceIdGenerator(),
      );

      await expectLater(
        () => useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: const TeamInvitationTarget(
            type: TeamInvitationTargetType.userId,
            value: 'user-2',
          ),
          proposedRelationship: ManagedPageRelationship.owner,
          proposedCapabilities: const <String>{},
        ),
        throwsA(
          isA<SendTeamInvitationException>().having(
            (SendTeamInvitationException error) => error.code,
            'code',
            'owner_relationship_not_invitable',
          ),
        ),
      );
    });

    test('rejects a malformed email or phone target', () async {
      final useCase = SendTeamInvitationUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(<String>{
            SendTeamInvitationUseCase.teamManageCapability,
          }),
        ),
        invitationRepository: _MemoryTeamInvitationRepository(),
        idGenerator: _SequenceIdGenerator(),
      );

      await expectLater(
        () => useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: const TeamInvitationTarget(
            type: TeamInvitationTargetType.email,
            value: 'not-an-email',
          ),
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        ),
        throwsA(isA<SendTeamInvitationException>()),
      );
      await expectLater(
        () => useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: const TeamInvitationTarget(
            type: TeamInvitationTargetType.phone,
            value: 'call-me',
          ),
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        ),
        throwsA(isA<SendTeamInvitationException>()),
      );
    });

    test(
      'resend within the cooldown window is an idempotent no-op',
      () async {
        final repository = _MemoryTeamInvitationRepository();
        DateTime now = DateTime.utc(2026, 1, 1);
        final useCase = SendTeamInvitationUseCase(
          workspaceRepository: _FakeWorkspaceRepository(
            accessWithCapabilities(<String>{
              SendTeamInvitationUseCase.teamManageCapability,
            }),
          ),
          invitationRepository: repository,
          idGenerator: _SequenceIdGenerator(),
          utcNow: () => now,
        );
        const target = TeamInvitationTarget(
          type: TeamInvitationTargetType.email,
          value: 'colleague@example.com',
        );

        final first = await useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: target,
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        );

        now = now.add(const Duration(hours: 1));
        final secondCallSameCooldown = await useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: target,
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        );

        expect(secondCallSameCooldown.id, first.id);
        expect(secondCallSameCooldown.resendCount, 0);
        expect(repository.saved, hasLength(1));
      },
    );

    test(
      'resend after the cooldown elapses increments resendCount and extends expiry',
      () async {
        final repository = _MemoryTeamInvitationRepository();
        DateTime now = DateTime.utc(2026, 1, 1);
        final useCase = SendTeamInvitationUseCase(
          workspaceRepository: _FakeWorkspaceRepository(
            accessWithCapabilities(<String>{
              SendTeamInvitationUseCase.teamManageCapability,
            }),
          ),
          invitationRepository: repository,
          idGenerator: _SequenceIdGenerator(),
          utcNow: () => now,
        );
        const target = TeamInvitationTarget(
          type: TeamInvitationTargetType.userId,
          value: 'user-2',
        );

        final first = await useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: target,
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        );

        now = now.add(TeamInvitationEntity.resendCooldown + const Duration(minutes: 1));
        final resent = await useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: target,
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        );

        expect(resent.id, first.id);
        expect(resent.resendCount, 1);
        expect(resent.expiresAtUtc, now.add(TeamInvitationEntity.defaultExpiry));
        expect(repository.saved, hasLength(1));
      },
    );

    test(
      'an expired pending invitation is not treated as active for dedup',
      () async {
        final repository = _MemoryTeamInvitationRepository();
        DateTime now = DateTime.utc(2026, 1, 1);
        final useCase = SendTeamInvitationUseCase(
          workspaceRepository: _FakeWorkspaceRepository(
            accessWithCapabilities(<String>{
              SendTeamInvitationUseCase.teamManageCapability,
            }),
          ),
          invitationRepository: repository,
          idGenerator: _SequenceIdGenerator(),
          utcNow: () => now,
        );
        const target = TeamInvitationTarget(
          type: TeamInvitationTargetType.userId,
          value: 'user-2',
        );

        final first = await useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: target,
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        );

        now = now.add(
          TeamInvitationEntity.defaultExpiry + const Duration(days: 1),
        );
        final second = await useCase(
          actingUserId: ownerId,
          pageId: pageId,
          target: target,
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
        );

        expect(second.id, isNot(first.id));
        expect(repository.saved, hasLength(2));
      },
    );
  });

  group('RevokeTeamInvitationUseCase', () {
    test('revokes a pending invitation for an authorized actor', () async {
      final repository = _MemoryTeamInvitationRepository();
      final invitation = TeamInvitationEntity(
        id: 'inv-1',
        pageId: pageId,
        target: const TeamInvitationTarget(
          type: TeamInvitationTargetType.userId,
          value: 'user-2',
        ),
        proposedRelationship: ManagedPageRelationship.editor,
        proposedCapabilities: const <String>{},
        invitedByUserId: ownerId,
        sentAtUtc: DateTime.utc(2026, 1, 1),
        expiresAtUtc: DateTime.utc(2026, 1, 8),
        status: TeamInvitationStatus.pending,
        revision: 1,
      );
      await repository.saveInvitation(invitation);

      final revokeUseCase = RevokeTeamInvitationUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(<String>{
            SendTeamInvitationUseCase.teamManageCapability,
          }),
        ),
        invitationRepository: repository,
      );

      final revoked = await revokeUseCase(
        actingUserId: ownerId,
        pageId: pageId,
        invitationId: 'inv-1',
      );

      expect(revoked.status, TeamInvitationStatus.revoked);
      expect(revoked.revision, 2);
    });

    test('revoking twice is an idempotent no-op, not an error', () async {
      final repository = _MemoryTeamInvitationRepository();
      await repository.saveInvitation(
        TeamInvitationEntity(
          id: 'inv-1',
          pageId: pageId,
          target: const TeamInvitationTarget(
            type: TeamInvitationTargetType.userId,
            value: 'user-2',
          ),
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
          invitedByUserId: ownerId,
          sentAtUtc: DateTime.utc(2026, 1, 1),
          expiresAtUtc: DateTime.utc(2026, 1, 8),
          status: TeamInvitationStatus.revoked,
          revision: 2,
        ),
      );

      final revokeUseCase = RevokeTeamInvitationUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(<String>{
            SendTeamInvitationUseCase.teamManageCapability,
          }),
        ),
        invitationRepository: repository,
      );

      final result = await revokeUseCase(
        actingUserId: ownerId,
        pageId: pageId,
        invitationId: 'inv-1',
      );

      expect(result.status, TeamInvitationStatus.revoked);
      expect(result.revision, 2);
    });

    test('rejects an actor without team-manage capability', () async {
      final repository = _MemoryTeamInvitationRepository();
      await repository.saveInvitation(
        TeamInvitationEntity(
          id: 'inv-1',
          pageId: pageId,
          target: const TeamInvitationTarget(
            type: TeamInvitationTargetType.userId,
            value: 'user-2',
          ),
          proposedRelationship: ManagedPageRelationship.editor,
          proposedCapabilities: const <String>{},
          invitedByUserId: ownerId,
          sentAtUtc: DateTime.utc(2026, 1, 1),
          expiresAtUtc: DateTime.utc(2026, 1, 8),
          status: TeamInvitationStatus.pending,
          revision: 1,
        ),
      );

      final revokeUseCase = RevokeTeamInvitationUseCase(
        workspaceRepository: _FakeWorkspaceRepository(
          accessWithCapabilities(<String>{'page.content.create'}),
        ),
        invitationRepository: repository,
      );

      await expectLater(
        () => revokeUseCase(
          actingUserId: ownerId,
          pageId: pageId,
          invitationId: 'inv-1',
        ),
        throwsA(isA<RevokeTeamInvitationException>()),
      );
    });
  });

  group('TeamInvitationEntity.effectiveStatusAt', () {
    test('folds a past-due pending invitation into expired without a write', () {
      final invitation = TeamInvitationEntity(
        id: 'inv-1',
        pageId: pageId,
        target: const TeamInvitationTarget(
          type: TeamInvitationTargetType.userId,
          value: 'user-2',
        ),
        proposedRelationship: ManagedPageRelationship.editor,
        proposedCapabilities: const <String>{},
        invitedByUserId: ownerId,
        sentAtUtc: DateTime.utc(2026, 1, 1),
        expiresAtUtc: DateTime.utc(2026, 1, 8),
        status: TeamInvitationStatus.pending,
        revision: 1,
      );

      expect(
        invitation.effectiveStatusAt(DateTime.utc(2026, 1, 7)),
        TeamInvitationStatus.pending,
      );
      expect(
        invitation.effectiveStatusAt(DateTime.utc(2026, 1, 9)),
        TeamInvitationStatus.expired,
      );
    });
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
  Future<void> saveActiveWorkspace(String userId, WorkspaceRef workspace) async {}

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
