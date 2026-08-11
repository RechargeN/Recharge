import 'scenario_budget_draft.dart';
import 'scenario_item_draft.dart';

enum ScenarioTravelMode { walking, bicycle, car, taxi, transit, other }

enum ScenarioLegSource { schedule, provider, manual, estimate, unknown }

enum ScenarioLegStatus { ready, loading, stale, failed, unavailable }

class ScenarioVehicleProfileDraft {
  const ScenarioVehicleProfileDraft({
    required this.enabled,
    this.label,
    this.passengerSeats,
  });

  const ScenarioVehicleProfileDraft.disabled()
    : enabled = false,
      label = null,
      passengerSeats = null;

  final bool enabled;
  final String? label;
  final int? passengerSeats;
}

class ScenarioLegDraft {
  const ScenarioLegDraft({
    required this.id,
    required this.dayId,
    required this.fromLocationId,
    required this.toLocationId,
    required this.mode,
    required this.source,
    required this.status,
    required this.cost,
    this.fromItemId,
    this.toItemId,
    this.distanceM,
    this.durationMinutes,
    this.displayPolyline = const <ScenarioGeoPointDraft>[],
    this.providerCode,
    this.warningCode,
    this.updatedAtUtc,
    this.scheduleSnapshot,
    this.lockedByUser = false,
  });

  final String id;
  final String dayId;
  final String? fromItemId;
  final String? toItemId;
  final String fromLocationId;
  final String toLocationId;
  final ScenarioTravelMode mode;
  final ScenarioLegSource source;
  final ScenarioLegStatus status;
  final double? distanceM;
  final int? durationMinutes;
  final ScenarioCostDraft cost;
  final List<ScenarioGeoPointDraft> displayPolyline;
  final String? providerCode;
  final String? warningCode;
  final DateTime? updatedAtUtc;
  final ScenarioScheduleSnapshotDraft? scheduleSnapshot;
  final bool lockedByUser;
}
