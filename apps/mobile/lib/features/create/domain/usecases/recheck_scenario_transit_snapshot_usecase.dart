import '../entities/scenario_item_draft.dart';
import '../entities/scenario_transit_mutation.dart';
import '../entities/scenario_transit_schedule.dart';
import '../repositories/scenario_transit_schedule_repository.dart';
import 'build_scenario_transit_snapshot_usecase.dart';
import 'search_scenario_transit_options_usecase.dart';

class RecheckScenarioTransitSnapshotUseCase {
  RecheckScenarioTransitSnapshotUseCase({
    required ScenarioTransitScheduleRepository repository,
    BuildScenarioTransitSnapshotUseCase buildSnapshot =
        const BuildScenarioTransitSnapshotUseCase(),
  }) : _search = SearchScenarioTransitOptionsUseCase(repository),
       _buildSnapshot = buildSnapshot;

  final SearchScenarioTransitOptionsUseCase _search;
  final BuildScenarioTransitSnapshotUseCase _buildSnapshot;

  Future<ScenarioTransitRecheckResult> call(
    ScenarioScheduleSnapshotDraft snapshot,
  ) async {
    final providerCode = snapshot.providerCode?.trim();
    final tripId = snapshot.tripId?.trim();
    final routeId = snapshot.routeId?.trim();
    final serviceId = snapshot.serviceId?.trim();
    final originStopId = snapshot.originStopId?.trim();
    final destinationStopId = snapshot.destinationStopId?.trim();
    final date = snapshot.serviceDate;
    if (providerCode == null ||
        providerCode.isEmpty ||
        providerCode == 'manual' ||
        tripId == null ||
        tripId.isEmpty ||
        routeId == null ||
        routeId.isEmpty ||
        serviceId == null ||
        serviceId.isEmpty ||
        originStopId == null ||
        originStopId.isEmpty ||
        destinationStopId == null ||
        destinationStopId.isEmpty ||
        date == null ||
        !date.isValid) {
      return const ScenarioTransitRecheckResult(
        status: ScenarioTransitRecheckStatus.invalidSnapshot,
      );
    }

    try {
      final result = await _search(
        ScenarioTransitSearchQuery(
          originStopId: originStopId,
          destinationStopId: destinationStopId,
          serviceDate: ScenarioTransitLocalDate(
            date.year,
            date.month,
            date.day,
          ),
          providerCodes: <String>{providerCode},
          exactTripId: tripId,
          limit: 1,
        ),
      );
      if (result.unavailableProviders.contains(providerCode)) {
        return const ScenarioTransitRecheckResult(
          status: ScenarioTransitRecheckStatus.unavailable,
        );
      }
      ScenarioTransitServiceOption? candidate;
      for (final option in result.options) {
        if (option.providerCode == providerCode && option.tripId == tripId) {
          candidate = option;
          break;
        }
      }
      if (candidate == null) {
        return const ScenarioTransitRecheckResult(
          status: ScenarioTransitRecheckStatus.notFound,
        );
      }
      late final ScenarioScheduleSnapshotDraft latest;
      try {
        latest = _buildSnapshot(candidate).snapshot;
      } on FormatException {
        return const ScenarioTransitRecheckResult(
          status: ScenarioTransitRecheckStatus.unavailable,
        );
      }
      final differences = _differences(snapshot, latest);
      return ScenarioTransitRecheckResult(
        status: differences.isEmpty
            ? ScenarioTransitRecheckStatus.unchanged
            : ScenarioTransitRecheckStatus.changed,
        candidate: candidate,
        differences: differences,
      );
    } on Object {
      return const ScenarioTransitRecheckResult(
        status: ScenarioTransitRecheckStatus.unavailable,
      );
    }
  }

  List<ScenarioTransitSnapshotDiff> _differences(
    ScenarioScheduleSnapshotDraft before,
    ScenarioScheduleSnapshotDraft after,
  ) {
    final result = <ScenarioTransitSnapshotDiff>[];
    void compare(String code, Object? oldValue, Object? newValue) {
      final oldText = _text(oldValue);
      final newText = _text(newValue);
      if (oldText != newText) {
        result.add(
          ScenarioTransitSnapshotDiff(
            fieldCode: code,
            before: oldText,
            after: newText,
          ),
        );
      }
    }

    compare('route', before.routeId, after.routeId);
    compare('service', before.serviceId, after.serviceId);
    compare('origin_stop', before.originStopId, after.originStopId);
    compare(
      'destination_stop',
      before.destinationStopId,
      after.destinationStopId,
    );
    compare(
      'departure',
      before.departureSecondsFromServiceDay,
      after.departureSecondsFromServiceDay,
    );
    compare(
      'arrival',
      before.arrivalSecondsFromServiceDay,
      after.arrivalSecondsFromServiceDay,
    );
    compare('carrier', before.carrierName, after.carrierName);
    compare('label', before.serviceLabel, after.serviceLabel);
    compare('feed_hash', before.feedSha256, after.feedSha256);
    compare('freshness', before.freshness.name, after.freshness.name);
    compare('retrieved_at', before.retrievedAtUtc, after.retrievedAtUtc);
    return List<ScenarioTransitSnapshotDiff>.unmodifiable(result);
  }

  String? _text(Object? value) => switch (value) {
    null => null,
    DateTime date => date.toUtc().toIso8601String(),
    _ => value.toString(),
  };
}
