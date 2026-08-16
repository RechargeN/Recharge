import '../../core/telemetry/analytics_service.dart';
import '../../features/create/domain/entities/scenario_item_draft.dart';
import '../../features/create/domain/entities/scenario_object_intake.dart';

enum ScenarioObjectIntakeTelemetryAction {
  open,
  preview,
  apply,
  cancel,
  retry,
  openTarget,
}

enum ScenarioObjectIntakeTelemetryResult {
  success,
  started,
  cancelled,
  disabled,
  authRequired,
  invalidInput,
  rejected,
  persistenceFailed,
}

enum ScenarioObjectIntakeBatchBucket { one, twoToFive, sixToTwenty }

enum ScenarioObjectIntakeTargetKind { existing, copied }

enum ScenarioObjectIntakePlacementKind { day, unscheduled }

enum ScenarioObjectIntakeSourceStatus {
  ready,
  stale,
  unresolved,
  unavailable,
  mixed,
}

class ScenarioObjectIntakeTelemetry {
  const ScenarioObjectIntakeTelemetry.disabled() : _analytics = null;

  const ScenarioObjectIntakeTelemetry(AnalyticsService analytics)
    : _analytics = analytics;

  final AnalyticsService? _analytics;

  void track({
    required ScenarioObjectIntakeIntent intent,
    required ScenarioObjectIntakeTelemetryAction action,
    required ScenarioObjectIntakeTelemetryResult result,
    ScenarioObjectIntakeTargetKind? targetKind,
    ScenarioObjectIntakePlacementKind? placement,
  }) {
    _analytics?.track(
      'scenario_object_intake_action',
      params: <String, Object?>{
        'source_surface': intent.sourceSurface.name,
        'action': _actionName(action),
        'result': _resultName(result),
        'batch_size_bucket': _batchBucket(intent.candidates.length),
        if (targetKind != null) 'target_kind': _targetName(targetKind),
        if (placement != null) 'placement': placement.name,
        'source_status': _sourceStatus(intent.candidates),
      },
    );
  }

  String _batchBucket(int count) => switch (count) {
    1 => ScenarioObjectIntakeBatchBucket.one.name,
    >= 2 && <= 5 => 'two_to_five',
    _ => 'six_to_twenty',
  };

  String _sourceStatus(List<ScenarioIntakeCandidate> candidates) {
    final statuses = candidates.map((value) => value.sourceStatus).toSet();
    if (statuses.length != 1) {
      return ScenarioObjectIntakeSourceStatus.mixed.name;
    }
    return switch (statuses.single) {
      ScenarioSourceStatus.ready => ScenarioObjectIntakeSourceStatus.ready.name,
      ScenarioSourceStatus.stale => ScenarioObjectIntakeSourceStatus.stale.name,
      ScenarioSourceStatus.unresolved =>
        ScenarioObjectIntakeSourceStatus.unresolved.name,
      ScenarioSourceStatus.unavailable =>
        ScenarioObjectIntakeSourceStatus.unavailable.name,
    };
  }

  String _actionName(ScenarioObjectIntakeTelemetryAction action) =>
      action == ScenarioObjectIntakeTelemetryAction.openTarget
      ? 'open_target'
      : action.name;

  String _resultName(ScenarioObjectIntakeTelemetryResult result) =>
      switch (result) {
        ScenarioObjectIntakeTelemetryResult.authRequired => 'auth_required',
        ScenarioObjectIntakeTelemetryResult.invalidInput => 'invalid_input',
        ScenarioObjectIntakeTelemetryResult.persistenceFailed =>
          'persistence_failed',
        _ => result.name,
      };

  String _targetName(ScenarioObjectIntakeTargetKind kind) =>
      kind == ScenarioObjectIntakeTargetKind.copied ? 'copied' : 'existing';
}
