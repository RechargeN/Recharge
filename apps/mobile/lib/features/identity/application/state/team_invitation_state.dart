import '../../domain/entities/team_invitation_entity.dart';

enum TeamInvitationStatusFlag {
  initial,
  loading,
  ready,
  sending,
  revoking,
  error,
}

class TeamInvitationState {
  const TeamInvitationState({
    required this.status,
    this.pageId,
    this.invitations = const <TeamInvitationEntity>[],
    this.message,
  });

  const TeamInvitationState.initial()
    : this(status: TeamInvitationStatusFlag.initial);

  final TeamInvitationStatusFlag status;
  final String? pageId;
  final List<TeamInvitationEntity> invitations;
  final String? message;

  bool get isBusy =>
      status == TeamInvitationStatusFlag.sending ||
      status == TeamInvitationStatusFlag.revoking;

  TeamInvitationState copyWith({
    TeamInvitationStatusFlag? status,
    String? pageId,
    List<TeamInvitationEntity>? invitations,
    String? message,
    bool clearMessage = false,
  }) {
    return TeamInvitationState(
      status: status ?? this.status,
      pageId: pageId ?? this.pageId,
      invitations: invitations ?? this.invitations,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
