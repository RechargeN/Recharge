import 'package:flutter/foundation.dart';

import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/team_invitation_entity.dart';
import '../../domain/repositories/team_invitation_repository.dart';
import '../../domain/usecases/revoke_team_invitation_usecase.dart';
import '../../domain/usecases/send_team_invitation_usecase.dart';
import '../state/team_invitation_state.dart';

/// Drives the sending member's side of `TeamInvitation` per
/// `TEAM_INVITATION_LOCAL_SLICE_SPEC.md` (`PP-03A`): load, send (or
/// idempotently resend) and revoke. Acceptance by the invited person is out
/// of scope and has no controller surface here.
class TeamInvitationController extends ChangeNotifier {
  TeamInvitationController({
    required TeamInvitationRepository invitationRepository,
    required SendTeamInvitationUseCase sendUseCase,
    required RevokeTeamInvitationUseCase revokeUseCase,
  }) : _invitationRepository = invitationRepository,
       _sendUseCase = sendUseCase,
       _revokeUseCase = revokeUseCase;

  final TeamInvitationRepository _invitationRepository;
  final SendTeamInvitationUseCase _sendUseCase;
  final RevokeTeamInvitationUseCase _revokeUseCase;

  TeamInvitationState _state = const TeamInvitationState.initial();
  TeamInvitationState get state => _state;

  int _operationRevision = 0;

  Future<void> ensureLoaded(String pageId) async {
    final String normalized = pageId.trim();
    if (normalized.isEmpty) return;
    if (_state.pageId == normalized &&
        (_state.status == TeamInvitationStatusFlag.ready ||
            _state.status == TeamInvitationStatusFlag.sending ||
            _state.status == TeamInvitationStatusFlag.revoking)) {
      return;
    }
    await _reload(normalized, TeamInvitationStatusFlag.loading);
  }

  Future<bool> send({
    required String actingUserId,
    required String pageId,
    required TeamInvitationTarget target,
    required ManagedPageRelationship proposedRelationship,
    required Set<String> proposedCapabilities,
  }) async {
    final String normalizedPageId = pageId.trim();
    final int operation = ++_operationRevision;
    _setState(
      _state.copyWith(
        status: TeamInvitationStatusFlag.sending,
        clearMessage: true,
      ),
    );
    try {
      await _sendUseCase(
        actingUserId: actingUserId,
        pageId: normalizedPageId,
        target: target,
        proposedRelationship: proposedRelationship,
        proposedCapabilities: proposedCapabilities,
      );
      if (operation != _operationRevision) return false;
      final List<TeamInvitationEntity> invitations = await _invitationRepository
          .loadForPage(normalizedPageId);
      if (operation != _operationRevision) return false;
      _setState(
        TeamInvitationState(
          status: TeamInvitationStatusFlag.ready,
          pageId: normalizedPageId,
          invitations: invitations,
          message: 'invitation_sent',
        ),
      );
      return true;
    } on SendTeamInvitationException catch (error) {
      if (operation != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: TeamInvitationStatusFlag.ready,
          message: _sendErrorMessage(error.code),
        ),
      );
      return false;
    } on Exception {
      if (operation != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: TeamInvitationStatusFlag.ready,
          message: 'invitation_send_failed',
        ),
      );
      return false;
    }
  }

  Future<bool> revoke({
    required String actingUserId,
    required String pageId,
    required String invitationId,
  }) async {
    final String normalizedPageId = pageId.trim();
    final int operation = ++_operationRevision;
    _setState(
      _state.copyWith(
        status: TeamInvitationStatusFlag.revoking,
        clearMessage: true,
      ),
    );
    try {
      await _revokeUseCase(
        actingUserId: actingUserId,
        pageId: normalizedPageId,
        invitationId: invitationId,
      );
      if (operation != _operationRevision) return false;
      final List<TeamInvitationEntity> invitations = await _invitationRepository
          .loadForPage(normalizedPageId);
      if (operation != _operationRevision) return false;
      _setState(
        TeamInvitationState(
          status: TeamInvitationStatusFlag.ready,
          pageId: normalizedPageId,
          invitations: invitations,
          message: 'invitation_revoked',
        ),
      );
      return true;
    } on RevokeTeamInvitationException catch (error) {
      if (operation != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: TeamInvitationStatusFlag.ready,
          message: _revokeErrorMessage(error.code),
        ),
      );
      return false;
    } on Exception {
      if (operation != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: TeamInvitationStatusFlag.ready,
          message: 'invitation_revoke_failed',
        ),
      );
      return false;
    }
  }

  Future<void> _reload(
    String pageId,
    TeamInvitationStatusFlag loadingAs,
  ) async {
    final int operation = ++_operationRevision;
    _setState(
      _state.copyWith(status: loadingAs, pageId: pageId, clearMessage: true),
    );
    try {
      final List<TeamInvitationEntity> invitations = await _invitationRepository
          .loadForPage(pageId);
      if (operation != _operationRevision) return;
      _setState(
        TeamInvitationState(
          status: TeamInvitationStatusFlag.ready,
          pageId: pageId,
          invitations: invitations,
        ),
      );
    } on Exception {
      if (operation != _operationRevision) return;
      _setState(
        _state.copyWith(
          status: TeamInvitationStatusFlag.error,
          message: 'invitations_load_failed',
        ),
      );
    }
  }

  /// L4.6: a stable code; the card turns it into text.
  static String _sendErrorMessage(String code) => switch (code) {
    'invitation_target_invalid' ||
    'owner_relationship_not_invitable' ||
    'inviter_not_active_member' ||
    'inviter_missing_team_manage_capability' ||
    'cannot_delegate_capability_not_held' => code,
    _ => 'invitation_send_failed',
  };

  static String _revokeErrorMessage(String code) => switch (code) {
    'actor_not_active_member' => 'revoke_actor_not_active_member',
    'actor_missing_team_manage_capability' =>
      'inviter_missing_team_manage_capability',
    'invitation_not_found' => code,
    _ => 'invitation_revoke_failed',
  };

  void _setState(TeamInvitationState value) {
    _state = value;
    notifyListeners();
  }
}
