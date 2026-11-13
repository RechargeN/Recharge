import '../../../../shared/primitives/id/id_generator.dart';
import '../entities/identity_access_snapshot.dart';
import '../entities/managed_page_membership_entity.dart';
import '../entities/team_invitation_entity.dart';
import '../repositories/identity_workspace_repository.dart';
import '../repositories/team_invitation_repository.dart';

class SendTeamInvitationException implements Exception {
  const SendTeamInvitationException(this.code);

  final String code;

  @override
  String toString() => 'SendTeamInvitationException($code)';
}

/// Sends (or idempotently resends) a `TeamInvitation` per
/// `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §22.1 / `PP-D14` / `PP-D28`.
///
/// Deliberately out of scope, matching `PPP-01A`'s own discipline for
/// deferred backend-dependent actions: acceptance by the invited person
/// (requires their own authenticated session, i.e. a second real device),
/// email/SMS delivery, and enumeration-safe existence disclosure for an
/// unknown target. Sending only ever writes a local, page-scoped record —
/// no network call is made.
class SendTeamInvitationUseCase {
  const SendTeamInvitationUseCase({
    required IdentityWorkspaceRepository workspaceRepository,
    required TeamInvitationRepository invitationRepository,
    required IdGenerator idGenerator,
    DateTime Function()? utcNow,
  }) : _workspaceRepository = workspaceRepository,
       _invitationRepository = invitationRepository,
       _idGenerator = idGenerator,
       _utcNow = utcNow ?? _systemUtcNow;

  static const String teamManageCapability = 'page.team.manage';

  final IdentityWorkspaceRepository _workspaceRepository;
  final TeamInvitationRepository _invitationRepository;
  final IdGenerator _idGenerator;
  final DateTime Function() _utcNow;

  Future<TeamInvitationEntity> call({
    required String actingUserId,
    required String pageId,
    required TeamInvitationTarget target,
    required ManagedPageRelationship proposedRelationship,
    required Set<String> proposedCapabilities,
  }) async {
    final String normalizedActor = actingUserId.trim();
    final String normalizedPageId = pageId.trim();
    if (normalizedActor.isEmpty || normalizedPageId.isEmpty) {
      throw const SendTeamInvitationException('actor_or_page_required');
    }
    if (!_isValidTarget(target)) {
      throw const SendTeamInvitationException('invitation_target_invalid');
    }
    if (proposedRelationship == ManagedPageRelationship.owner) {
      // Ownership is transferred, never granted by invitation (§5.5 there).
      throw const SendTeamInvitationException(
        'owner_relationship_not_invitable',
      );
    }

    final IdentityAccessSnapshot access = await _workspaceRepository
        .loadAccessSnapshot(normalizedActor);
    if (access.userId != normalizedActor) {
      throw const SendTeamInvitationException('access_snapshot_mismatch');
    }
    final ManagedPageMembershipEntity? membership = access.membershipFor(
      normalizedPageId,
    );
    if (membership == null || !membership.isActive) {
      throw const SendTeamInvitationException('inviter_not_active_member');
    }
    if (!membership.hasCapability(teamManageCapability)) {
      throw const SendTeamInvitationException(
        'inviter_missing_team_manage_capability',
      );
    }
    // PP-D28: an inviter may delegate only capabilities they themselves
    // hold — never a superset of their own grant.
    if (!proposedCapabilities.every(membership.hasCapability)) {
      throw const SendTeamInvitationException(
        'cannot_delegate_capability_not_held',
      );
    }

    final DateTime nowUtc = _utcNow().toUtc();
    final List<TeamInvitationEntity> existing = await _invitationRepository
        .loadForPage(normalizedPageId);
    final TeamInvitationEntity? activeForTarget = _findActivePending(
      existing,
      target,
      nowUtc,
    );

    if (activeForTarget != null) {
      return _resendIdempotently(activeForTarget, nowUtc);
    }

    final TeamInvitationEntity invitation = TeamInvitationEntity(
      id: _idGenerator.generate(),
      pageId: normalizedPageId,
      target: target,
      proposedRelationship: proposedRelationship,
      proposedCapabilities: Set<String>.unmodifiable(proposedCapabilities),
      invitedByUserId: normalizedActor,
      sentAtUtc: nowUtc,
      expiresAtUtc: nowUtc.add(TeamInvitationEntity.defaultExpiry),
      status: TeamInvitationStatus.pending,
      revision: 1,
    );
    await _invitationRepository.saveInvitation(invitation);
    return invitation;
  }

  Future<TeamInvitationEntity> _resendIdempotently(
    TeamInvitationEntity existing,
    DateTime nowUtc,
  ) async {
    final DateTime lastSignal = existing.lastResentAtUtc ?? existing.sentAtUtc;
    final bool withinCooldown =
        nowUtc.difference(lastSignal) < TeamInvitationEntity.resendCooldown;
    if (withinCooldown) {
      // Idempotent no-op: same record, no state change, no error.
      return existing;
    }
    final TeamInvitationEntity resent = existing.copyWith(
      resendCount: existing.resendCount + 1,
      lastResentAtUtc: nowUtc,
      expiresAtUtc: nowUtc.add(TeamInvitationEntity.defaultExpiry),
      revision: existing.revision + 1,
    );
    await _invitationRepository.saveInvitation(resent);
    return resent;
  }

  static TeamInvitationEntity? _findActivePending(
    List<TeamInvitationEntity> existing,
    TeamInvitationTarget target,
    DateTime nowUtc,
  ) {
    for (final TeamInvitationEntity invitation in existing) {
      if (invitation.target == target &&
          invitation.effectiveStatusAt(nowUtc) ==
              TeamInvitationStatus.pending) {
        return invitation;
      }
    }
    return null;
  }

  static bool _isValidTarget(TeamInvitationTarget target) {
    final String value = target.value.trim();
    if (value.isEmpty) return false;
    switch (target.type) {
      case TeamInvitationTargetType.userId:
        return value.isNotEmpty;
      case TeamInvitationTargetType.email:
        return value.contains('@') &&
            value.indexOf('@') > 0 &&
            value.indexOf('@') < value.length - 1;
      case TeamInvitationTargetType.phone:
        return RegExp(r'^\+?[0-9]{6,15}$').hasMatch(value);
    }
  }

  static DateTime _systemUtcNow() => DateTime.now().toUtc();
}
