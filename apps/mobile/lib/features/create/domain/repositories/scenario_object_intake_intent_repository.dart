import '../entities/scenario_object_intake_session.dart';

abstract interface class ScenarioObjectIntakeIntentRepository {
  Future<void> put(ScenarioObjectIntakeSession session);

  Future<ScenarioObjectIntakeSession?> load({
    required String ownerId,
    required String intentId,
  });

  Future<void> markConsumed({
    required String ownerId,
    required String intentId,
    required String targetDraftId,
    required int targetRevision,
  });

  Future<void> discard({required String ownerId, required String intentId});
}
