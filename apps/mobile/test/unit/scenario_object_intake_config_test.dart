import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/scenario_object_intake_config.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_object_intake.dart';

void main() {
  test('validates version, bounded batch size and bounded positive TTL', () {
    expect(const ScenarioObjectIntakeConfig().validated(), isNotNull);
    expect(
      () => const ScenarioObjectIntakeConfig(maxBatchSize: 0).validated(),
      throwsStateError,
    );
    expect(
      () => const ScenarioObjectIntakeConfig(maxBatchSize: 21).validated(),
      throwsStateError,
    );
    expect(
      () => const ScenarioObjectIntakeConfig(
        intentTtl: Duration.zero,
      ).validated(),
      throwsStateError,
    );
    expect(
      () => const ScenarioObjectIntakeConfig(schemaVersion: 99).validated(),
      throwsStateError,
    );
  });

  test('surface and multi-select flags fail closed from one policy', () {
    const config = ScenarioObjectIntakeConfig(
      detailsEnabled: false,
      multiSelectEnabled: false,
      maxBatchSize: 5,
    );

    expect(config.allowsSurface(ScenarioIntakeSourceSurface.details), isFalse);
    expect(
      config.allowsIntent(_intent(ScenarioIntakeSourceSurface.search, 1)),
      isTrue,
    );
    expect(
      config.allowsIntent(_intent(ScenarioIntakeSourceSurface.search, 2)),
      isFalse,
    );
    expect(
      config.allowsIntent(_intent(ScenarioIntakeSourceSurface.map, 6)),
      isFalse,
    );
  });
}

ScenarioObjectIntakeIntent _intent(
  ScenarioIntakeSourceSurface surface,
  int count,
) => ScenarioObjectIntakeIntent(
  contractVersion: ScenarioObjectIntakeIntent.currentContractVersion,
  intentId: 'private-intent',
  requesterId: 'private-owner',
  sourceSurface: surface,
  candidates: List<ScenarioIntakeCandidate>.generate(
    count,
    (index) => ScenarioIntakeCandidate(
      ref: ScenarioObjectRef(
        objectId: 'private-object-$index',
        objectType: ScenarioCatalogObjectType.place,
      ),
      snapshot: ScenarioObjectSnapshotDraft(
        title: 'Private title $index',
        checkedAtUtc: DateTime.utc(2026, 8, 3),
      ),
      sourceStatus: ScenarioSourceStatus.ready,
    ),
  ),
);
