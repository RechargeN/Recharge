import '../entities/scenario_draft_entity.dart';

class QuickPlanInvitation {
  const QuickPlanInvitation({
    required this.planId,
    required this.ownerId,
    required this.inviteeId,
    required this.invitationId,
    required this.generation,
    required this.status,
  });
  final String planId, ownerId, inviteeId, invitationId, status;
  final int generation;
  factory QuickPlanInvitation.fromMap(Map raw) => QuickPlanInvitation(
    planId: raw['planId'] as String,
    ownerId: raw['ownerId'] as String,
    inviteeId: raw['inviteeId'] as String,
    invitationId: raw['invitationId'] as String,
    generation: raw['generation'] as int,
    status: raw['status'] as String,
  );
}

abstract interface class QuickPlanRepository {
  String? get actorId;
  Future<void> restore();
  Future<void> refresh(String id);
  Future<void> save(ScenarioDraftEntity plan, {required int expectedRevision});
  Future<void> delete(String id, {required int expectedRevision});
  Future<void> importJson(String source);
  ScenarioDraftEntity? cached(String id);
  int? serverRevision(String id);
  bool hasPending(String id);
  List<Map<String, Object?>> get conflicts;
  void clearVisible();
  Future<List<QuickPlanInvitation>> invitations();
  Future<void> invite(
    String planId,
    String userId, {
    QuickPlanInvitation? previous,
  });
  Future<void> invitationAction(String action, QuickPlanInvitation invitation);
  Future<ScenarioDraftEntity> readInvited(QuickPlanInvitation invitation);
}
