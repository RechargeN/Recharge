import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/scenario_object_intake_telemetry.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_object_intake.dart';

void main() {
  test('payload is allowlisted buckets and contains no content or ids', () {
    final analytics = _Analytics();
    ScenarioObjectIntakeTelemetry(analytics).track(
      intent: _intent,
      action: ScenarioObjectIntakeTelemetryAction.apply,
      result: ScenarioObjectIntakeTelemetryResult.success,
      targetKind: ScenarioObjectIntakeTargetKind.copied,
      placement: ScenarioObjectIntakePlacementKind.unscheduled,
    );

    expect(analytics.eventName, 'scenario_object_intake_action');
    expect(analytics.params, <String, Object?>{
      'source_surface': 'search',
      'action': 'apply',
      'result': 'success',
      'batch_size_bucket': 'two_to_five',
      'target_kind': 'copied',
      'placement': 'unscheduled',
      'source_status': 'mixed',
    });
    expect(
      analytics.params.keys,
      everyElement(
        isIn(<String>[
          'source_surface',
          'action',
          'result',
          'batch_size_bucket',
          'target_kind',
          'placement',
          'source_status',
        ]),
      ),
    );
    final payload = analytics.params.toString();
    for (final privateValue in <String>[
      'private-intent-id',
      'private-owner-id',
      'private-object-id',
      'Secret title',
      '56.9',
      '24.1',
    ]) {
      expect(payload, isNot(contains(privateValue)));
    }
  });
}

final _intent = ScenarioObjectIntakeIntent(
  contractVersion: ScenarioObjectIntakeIntent.currentContractVersion,
  intentId: 'private-intent-id',
  requesterId: 'private-owner-id',
  sourceSurface: ScenarioIntakeSourceSurface.search,
  candidates: <ScenarioIntakeCandidate>[
    ScenarioIntakeCandidate(
      ref: const ScenarioObjectRef(
        objectId: 'private-object-id-1',
        objectType: ScenarioCatalogObjectType.place,
      ),
      snapshot: ScenarioObjectSnapshotDraft(
        title: 'Secret title',
        checkedAtUtc: DateTime.utc(2026, 8, 3),
      ),
      sourceStatus: ScenarioSourceStatus.ready,
      location: const ScenarioIntakeLocationSnapshot(
        title: 'Secret address',
        point: ScenarioGeoPointDraft(latitude: 56.9, longitude: 24.1),
        disclosure: ScenarioLocationDisclosure.public,
      ),
    ),
    ScenarioIntakeCandidate(
      ref: const ScenarioObjectRef(
        objectId: 'private-object-id-2',
        objectType: ScenarioCatalogObjectType.event,
      ),
      snapshot: ScenarioObjectSnapshotDraft(
        title: 'Another secret',
        checkedAtUtc: DateTime.utc(2026, 8, 3),
      ),
      sourceStatus: ScenarioSourceStatus.stale,
    ),
  ],
);

class _Analytics implements AnalyticsService {
  String? eventName;
  Map<String, Object?> params = const <String, Object?>{};

  @override
  void track(
    String eventName, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    this.eventName = eventName;
    this.params = Map<String, Object?>.unmodifiable(params);
  }
}
