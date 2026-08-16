import '../../../core/telemetry/analytics_service.dart';
import '../domain/entities/scenario_item_draft.dart';
import '../domain/entities/scenario_transit_mutation.dart';
import '../domain/entities/scenario_transit_schedule.dart';

enum ScenarioTransitTelemetryAction { apply, replace, recheck }

enum ScenarioTransitTelemetryResult {
  success,
  revisionConflict,
  invalidSelection,
  missingTarget,
  targetNotOfficial,
  unchanged,
  changed,
  notFound,
  unavailable,
  invalidSnapshot,
}

class ScenarioTransitTelemetry {
  const ScenarioTransitTelemetry.disabled() : _analytics = null;

  const ScenarioTransitTelemetry(AnalyticsService analytics)
    : _analytics = analytics;

  final AnalyticsService? _analytics;

  void track({
    required ScenarioTransitTelemetryAction action,
    required ScenarioTransitTelemetryResult result,
    ScenarioScheduleFreshness? freshness,
  }) {
    _analytics?.track(
      'scenario_transit_action',
      params: <String, Object?>{
        'action': action.name,
        'result': result.name,
        if (freshness != null) 'freshness': freshness.name,
      },
    );
  }

  void trackMutation({
    required bool replacing,
    required ScenarioTransitMutationResult mutation,
    required ScenarioTransitFreshness freshness,
  }) {
    track(
      action: replacing
          ? ScenarioTransitTelemetryAction.replace
          : ScenarioTransitTelemetryAction.apply,
      result: mutation.accepted
          ? ScenarioTransitTelemetryResult.success
          : mutation.failure!.telemetryResult,
      freshness: freshness.scheduleFreshness,
    );
  }

  void trackRecheck(ScenarioTransitRecheckResult recheck) {
    track(
      action: ScenarioTransitTelemetryAction.recheck,
      result: recheck.status.telemetryResult,
      freshness: recheck.candidate?.manifest.freshness.scheduleFreshness,
    );
  }
}

extension on ScenarioTransitMutationFailure {
  ScenarioTransitTelemetryResult get telemetryResult => switch (this) {
    ScenarioTransitMutationFailure.revisionConflict =>
      ScenarioTransitTelemetryResult.revisionConflict,
    ScenarioTransitMutationFailure.invalidSelection =>
      ScenarioTransitTelemetryResult.invalidSelection,
    ScenarioTransitMutationFailure.missingTarget =>
      ScenarioTransitTelemetryResult.missingTarget,
    ScenarioTransitMutationFailure.targetNotOfficial =>
      ScenarioTransitTelemetryResult.targetNotOfficial,
  };
}

extension on ScenarioTransitRecheckStatus {
  ScenarioTransitTelemetryResult get telemetryResult => switch (this) {
    ScenarioTransitRecheckStatus.unchanged =>
      ScenarioTransitTelemetryResult.unchanged,
    ScenarioTransitRecheckStatus.changed =>
      ScenarioTransitTelemetryResult.changed,
    ScenarioTransitRecheckStatus.notFound =>
      ScenarioTransitTelemetryResult.notFound,
    ScenarioTransitRecheckStatus.unavailable =>
      ScenarioTransitTelemetryResult.unavailable,
    ScenarioTransitRecheckStatus.invalidSnapshot =>
      ScenarioTransitTelemetryResult.invalidSnapshot,
  };
}

extension on ScenarioTransitFreshness {
  ScenarioScheduleFreshness get scheduleFreshness => switch (this) {
    ScenarioTransitFreshness.current => ScenarioScheduleFreshness.current,
    ScenarioTransitFreshness.stale => ScenarioScheduleFreshness.stale,
    ScenarioTransitFreshness.unknown => ScenarioScheduleFreshness.unknown,
    ScenarioTransitFreshness.unavailable => ScenarioScheduleFreshness.unknown,
  };
}
