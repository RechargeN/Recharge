import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/scenario_transit_telemetry.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_mutation.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';

void main() {
  test('payload is enum-only and contains no content or identity fields', () {
    final analytics = _Analytics();
    final telemetry = ScenarioTransitTelemetry(analytics);
    telemetry.trackMutation(
      replacing: true,
      mutation: ScenarioTransitMutationResult.accepted(
        draft: _draft,
        itemId: 'private-item-id',
      ),
      freshness: ScenarioTransitFreshness.current,
    );

    expect(analytics.eventName, 'scenario_transit_action');
    expect(analytics.params, <String, Object?>{
      'action': 'replace',
      'result': 'success',
      'freshness': 'current',
    });
    expect(
      analytics.params.keys,
      everyElement(isIn(<String>['action', 'result', 'freshness'])),
    );
    expect(analytics.params.toString(), isNot(contains('private-item-id')));
  });

  test('recheck failure emits typed result without snapshot data', () {
    final analytics = _Analytics();
    ScenarioTransitTelemetry(analytics).trackRecheck(
      const ScenarioTransitRecheckResult(
        status: ScenarioTransitRecheckStatus.unavailable,
      ),
    );

    expect(analytics.params, <String, Object?>{
      'action': 'recheck',
      'result': 'unavailable',
    });
  });
}

final _draft = ScenarioDraftData.defaults();

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
