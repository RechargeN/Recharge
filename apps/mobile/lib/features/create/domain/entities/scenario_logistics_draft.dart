import 'scenario_budget_draft.dart';
import 'scenario_item_draft.dart';

enum ScenarioTravelMode { walking, bicycle, car, taxi, transit, other }

enum ScenarioLegSource { schedule, provider, manual, estimate, unknown }

enum ScenarioLegStatus { ready, loading, stale, failed, unavailable }

class ScenarioVehicleProfileDraft {
  const ScenarioVehicleProfileDraft({
    required this.enabled,
    required this.includeFuelInBudget,
    this.label,
    this.litresPer100Km,
    this.fuelPricePerLitre,
    this.passengerSeats,
  });

  const ScenarioVehicleProfileDraft.disabled()
    : enabled = false,
      includeFuelInBudget = false,
      label = null,
      litresPer100Km = null,
      fuelPricePerLitre = null,
      passengerSeats = null;

  final bool enabled;
  final bool includeFuelInBudget;
  final String? label;
  final double? litresPer100Km;
  final ScenarioMoneyDraft? fuelPricePerLitre;
  final int? passengerSeats;

  int? fuelCostMinorUnits(double? distanceM) {
    if (!enabled ||
        !includeFuelInBudget ||
        distanceM == null ||
        distanceM < 0 ||
        litresPer100Km == null ||
        litresPer100Km! <= 0 ||
        fuelPricePerLitre == null ||
        !fuelPricePerLitre!.isStructurallyValid) {
      return null;
    }
    final double distanceKm = distanceM / 1000;
    return (distanceKm / 100 * litresPer100Km! * fuelPricePerLitre!.minorUnits)
        .round();
  }
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
