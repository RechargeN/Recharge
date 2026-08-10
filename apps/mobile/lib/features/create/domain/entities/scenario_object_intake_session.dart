import 'scenario_object_intake.dart';

enum ScenarioObjectIntakeSessionStatus { pending, consumed }

class ScenarioObjectIntakeSession {
  const ScenarioObjectIntakeSession({
    required this.schemaVersion,
    required this.intent,
    required this.createdAtUtc,
    required this.expiresAtUtc,
    required this.status,
    this.consumedTargetDraftId,
    this.consumedTargetRevision,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final ScenarioObjectIntakeIntent intent;
  final DateTime createdAtUtc;
  final DateTime expiresAtUtc;
  final ScenarioObjectIntakeSessionStatus status;
  final String? consumedTargetDraftId;
  final int? consumedTargetRevision;

  bool isExpiredAt(DateTime nowUtc) => !nowUtc.toUtc().isBefore(expiresAtUtc);

  ScenarioObjectIntakeSession consumed({
    required String targetDraftId,
    required int targetRevision,
  }) => ScenarioObjectIntakeSession(
    schemaVersion: schemaVersion,
    intent: intent,
    createdAtUtc: createdAtUtc,
    expiresAtUtc: expiresAtUtc,
    status: ScenarioObjectIntakeSessionStatus.consumed,
    consumedTargetDraftId: targetDraftId,
    consumedTargetRevision: targetRevision,
  );
}
