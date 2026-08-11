import '../../domain/entities/scenario_object_intake_session.dart';
import '../../domain/repositories/scenario_object_intake_intent_repository.dart';
import '../datasources/scenario_object_intake_local_datasource.dart';

class ScenarioObjectIntakeRepositoryImpl
    implements ScenarioObjectIntakeIntentRepository {
  const ScenarioObjectIntakeRepositoryImpl(this._localDataSource);

  final ScenarioObjectIntakeLocalDataSource _localDataSource;

  @override
  Future<void> put(ScenarioObjectIntakeSession session) {
    if (session.schemaVersion !=
            ScenarioObjectIntakeSession.currentSchemaVersion ||
        session.intent.contractVersion != 1 ||
        session.intent.candidates.isEmpty ||
        session.intent.candidates.length > 20 ||
        !session.expiresAtUtc.isAfter(session.createdAtUtc)) {
      throw const FormatException('Invalid Scenario intake session.');
    }
    return _localDataSource.put(session);
  }

  @override
  Future<ScenarioObjectIntakeSession?> load({
    required String ownerId,
    required String intentId,
  }) => _localDataSource.load(ownerId: ownerId, intentId: intentId);

  @override
  Future<void> markConsumed({
    required String ownerId,
    required String intentId,
    required String targetDraftId,
    required int targetRevision,
  }) async {
    final current = await load(ownerId: ownerId, intentId: intentId);
    if (current == null || current.intent.requesterId != ownerId) {
      throw StateError('Scenario intake intent is unavailable.');
    }
    if (current.status == ScenarioObjectIntakeSessionStatus.consumed) {
      if (current.consumedTargetDraftId == targetDraftId &&
          current.consumedTargetRevision == targetRevision) {
        return;
      }
      throw StateError('Scenario intake intent is already consumed.');
    }
    await _localDataSource.replace(
      current.consumed(
        targetDraftId: targetDraftId,
        targetRevision: targetRevision,
      ),
    );
  }

  @override
  Future<void> discard({required String ownerId, required String intentId}) =>
      _localDataSource.discard(ownerId: ownerId, intentId: intentId);
}
