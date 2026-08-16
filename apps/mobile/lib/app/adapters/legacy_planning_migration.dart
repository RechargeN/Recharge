import 'legacy_planning_link_classifier.dart';

enum LegacyPlanningMigrationResult { migrated, retainedAmbiguous, unsupported }

class LegacyPlanningMigrationRecord {
  const LegacyPlanningMigrationRecord({
    required this.sourceRecordId,
    required this.sourcePayload,
    required this.classification,
    required this.result,
    this.targetKind,
    this.targetId,
  });

  final String sourceRecordId;
  final String sourcePayload;
  final LegacyPlanningPayloadKind classification;
  final LegacyPlanningMigrationResult result;
  final LegacyPlanningPayloadKind? targetKind;
  final String? targetId;

  bool get mayDeleteSource => false;
}

class LegacyPlanningMigrationPlanner {
  const LegacyPlanningMigrationPlanner({
    LegacyPlanningLinkClassifier classifier =
        const LegacyPlanningLinkClassifier(),
  }) : _classifier = classifier;

  final LegacyPlanningLinkClassifier _classifier;

  LegacyPlanningMigrationRecord plan({
    required String sourceRecordId,
    required String sourcePayload,
  }) {
    final classification = _classifier.classify(sourcePayload);
    final targetId = classification.targetId;
    final isTyped =
        targetId != null &&
        (classification.kind == LegacyPlanningPayloadKind.quickPlan ||
            classification.kind == LegacyPlanningPayloadKind.scenario ||
            classification.kind == LegacyPlanningPayloadKind.route);
    return LegacyPlanningMigrationRecord(
      sourceRecordId: sourceRecordId,
      sourcePayload: sourcePayload,
      classification: classification.kind,
      result: isTyped
          ? LegacyPlanningMigrationResult.migrated
          : classification.kind == LegacyPlanningPayloadKind.ambiguous
          ? LegacyPlanningMigrationResult.retainedAmbiguous
          : LegacyPlanningMigrationResult.unsupported,
      targetKind: isTyped ? classification.kind : null,
      targetId: isTyped ? targetId : null,
    );
  }
}
