import '../entities/identity_access_snapshot.dart';
import '../entities/managed_page_membership_entity.dart';
import '../entities/team_invitation_entity.dart';
import '../repositories/identity_workspace_repository.dart';
import '../repositories/team_invitation_repository.dart';
import 'send_team_invitation_usecase.dart';

class RevokeTeamInvitationException implements Exception {
  const RevokeTeamInvitationException(this.code);

  final String code;

  @override
  String toString() => 'RevokeTeamInvitationException($code)';
}

/// Revokes a pending `TeamInvitation`. Idempotent: revoking an
/// already-revoked or already-expired invitation is a safe no-op, never an
/// error — matching `PP-D28`'s idempotency requirement.
class RevokeTeamInvitationUseCase {
  const RevokeTeamInvitationUseCase({
    required IdentityWorkspaceRepository workspaceRepository,
    required TeamInvitationRepository invitationRepository,
  }) : _workspaceRepository = workspaceRepository,
       _invitationRepository = invitationRepository;

  final IdentityWorkspaceRepository _workspaceRepository;
  final TeamInvitationRepository _invitationRepository;

  Future<TeamInvitationEntity> call({
    required String actingUserId,
    required String pageId,
    required String invitationId,
  }) async {
    final String normalizedActor = actingUserId.trim();
    final String normalizedPageId = pageId.trim();
    if (normalizedActor.isEmpty ||
        normalizedPageId.isEmpty ||
        invitationId.trim().isEmpty) {
      throw const RevokeTeamInvitationException(
        'actor_page_or_invitation_required',
      );
    }

    final IdentityAccessSnapshot access = await _workspaceRepository
        .loadAccessSnapshot(normalizedActor);
    final ManagedPageMembershipEntity? membership = access.membershipFor(
      normalizedPageId,
    );
    if (membership == null || !membership.isActive) {
      throw const RevokeTeamInvitationException('actor_not_active_member');
    }
    if (!membership.hasCapability(
      SendTeamInvitationUseCase.teamManageCapability,
    )) {
      throw const RevokeTeamInvitationException(
        'actor_missing_team_manage_capability',
      );
    }

    final List<TeamInvitationEntity> existing = await _invitationRepository
        .loadForPage(normalizedPageId);
    final TeamInvitationEntity? found = existing
        .where(
          (TeamInvitationEntity invitation) => invitation.id == invitationId,
        )
        .cast<TeamInvitationEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (found == null) {
      throw const RevokeTeamInvitationException('invitation_not_found');
    }

    if (found.status != TeamInvitationStatus.pending) {
      // Already revoked/expired: idempotent no-op.
      return found;
    }

    final TeamInvitationEntity revoked = found.copyWith(
      status: TeamInvitationStatus.revoked,
      revision: found.revision + 1,
    );
    await _invitationRepository.saveInvitation(revoked);
    return revoked;
  }
}
