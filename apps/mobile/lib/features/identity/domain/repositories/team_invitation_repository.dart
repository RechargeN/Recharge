import '../entities/team_invitation_entity.dart';

abstract class TeamInvitationRepository {
  Future<List<TeamInvitationEntity>> loadForPage(String pageId);

  Future<void> saveInvitation(TeamInvitationEntity invitation);
}
