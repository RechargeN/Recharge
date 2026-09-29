import '../../domain/entities/team_invitation_entity.dart';
import '../../domain/repositories/team_invitation_repository.dart';
import '../datasources/team_invitation_local_datasource.dart';

class TeamInvitationRepositoryImpl implements TeamInvitationRepository {
  const TeamInvitationRepositoryImpl(this._localDataSource);

  final TeamInvitationLocalDataSource _localDataSource;

  @override
  Future<List<TeamInvitationEntity>> loadForPage(String pageId) {
    return _localDataSource.loadForPage(pageId);
  }

  @override
  Future<void> saveInvitation(TeamInvitationEntity invitation) async {
    final List<TeamInvitationEntity> existing = await _localDataSource
        .loadForPage(invitation.pageId);
    final int index = existing.indexWhere(
      (TeamInvitationEntity item) => item.id == invitation.id,
    );
    final List<TeamInvitationEntity> updated = List<TeamInvitationEntity>.of(
      existing,
    );
    if (index >= 0) {
      updated[index] = invitation;
    } else {
      updated.add(invitation);
    }
    await _localDataSource.saveForPage(invitation.pageId, updated);
  }
}
