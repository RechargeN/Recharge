import '../entities/scenario_item_draft.dart';
import '../entities/scenario_transit_schedule.dart';

class ScenarioTransitSnapshotBuildResult {
  const ScenarioTransitSnapshotBuildResult({
    required this.source,
    required this.durationMinutes,
  });

  final ScenarioPlannedTransportSourceDraft source;
  final int durationMinutes;

  ScenarioScheduleSnapshotDraft get snapshot => source.scheduleSnapshot!;
}

class BuildScenarioTransitSnapshotUseCase {
  const BuildScenarioTransitSnapshotUseCase();

  ScenarioTransitSnapshotBuildResult call(ScenarioTransitServiceOption option) {
    _validate(option);
    final manifest = option.manifest;
    final carrierName = _nullableTrimmed(option.agencyName);
    final routeLabel = _nullableTrimmed(option.routeLabel);
    final headsign = _nullableTrimmed(option.headsign);
    final serviceLabel = routeLabel ?? headsign ?? option.routeId.trim();
    final snapshot = ScenarioScheduleSnapshotDraft(
      freshness: _freshness(manifest.freshness),
      providerCode: option.providerCode.trim(),
      providerDisplayName: manifest.providerDisplayName.trim(),
      licenseName: manifest.licenseName.trim(),
      tripId: option.tripId.trim(),
      routeId: option.routeId.trim(),
      serviceId: option.serviceId.trim(),
      originStopId: option.origin.id.trim(),
      destinationStopId: option.destination.id.trim(),
      feedSha256: manifest.sha256.toLowerCase(),
      serviceDate: ScenarioLocalDateDraft(
        year: option.serviceDate.year,
        month: option.serviceDate.month,
        day: option.serviceDate.day,
      ),
      retrievedAtUtc: manifest.retrievedAtUtc.toUtc(),
      carrierName: carrierName,
      serviceLabel: serviceLabel,
      originLabel: option.origin.name.trim(),
      destinationLabel: option.destination.name.trim(),
      plannedDeparture: _localTime(option.departure),
      plannedArrival: _localTime(option.arrival),
      departureSecondsFromServiceDay: option.departure.secondsFromServiceDay,
      arrivalSecondsFromServiceDay: option.arrival.secondsFromServiceDay,
      departureDayOffset: option.departure.dayOffset,
      arrivalDayOffset: option.arrival.dayOffset,
      sourceUrl: manifest.sourceUrl.trim(),
    );
    return ScenarioTransitSnapshotBuildResult(
      source: ScenarioPlannedTransportSourceDraft(
        kind: _transportKind(option.mode),
        carrierName: carrierName,
        publicServiceLabel: serviceLabel,
        scheduleSnapshot: snapshot,
      ),
      durationMinutes: option.durationMinutes,
    );
  }

  void _validate(ScenarioTransitServiceOption option) {
    final manifest = option.manifest;
    final requiredValues = <String>[
      option.providerCode,
      option.tripId,
      option.routeId,
      option.serviceId,
      option.origin.id,
      option.origin.name,
      option.destination.id,
      option.destination.name,
      manifest.providerCode,
      manifest.providerDisplayName,
      manifest.licenseName,
      manifest.sourceUrl,
      manifest.sha256,
    ];
    if (requiredValues.any((String value) => value.trim().isEmpty)) {
      throw const FormatException('Transit option contains empty provenance.');
    }
    if (!option.serviceDate.isValid ||
        option.providerCode != manifest.providerCode ||
        option.origin.providerCode != option.providerCode ||
        option.destination.providerCode != option.providerCode ||
        option.origin.id == option.destination.id) {
      throw const FormatException('Transit option relations are invalid.');
    }
    if (option.departure.secondsFromServiceDay < 0 ||
        option.arrival.secondsFromServiceDay <=
            option.departure.secondsFromServiceDay ||
        option.arrival.secondsFromServiceDay >= 48 * Duration.secondsPerHour) {
      throw const FormatException('Transit option chronology is invalid.');
    }
    final sourceUri = Uri.tryParse(manifest.sourceUrl);
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(manifest.sha256) ||
        sourceUri == null ||
        sourceUri.scheme.toLowerCase() != 'https' ||
        sourceUri.host.isEmpty) {
      throw const FormatException('Transit feed provenance is invalid.');
    }
    if (manifest.freshness == ScenarioTransitFreshness.unavailable) {
      throw const FormatException(
        'Unavailable feed cannot produce a snapshot.',
      );
    }
  }

  ScenarioScheduleFreshness _freshness(ScenarioTransitFreshness value) {
    return switch (value) {
      ScenarioTransitFreshness.current => ScenarioScheduleFreshness.current,
      ScenarioTransitFreshness.stale => ScenarioScheduleFreshness.stale,
      ScenarioTransitFreshness.unknown => ScenarioScheduleFreshness.unknown,
      ScenarioTransitFreshness.unavailable => throw const FormatException(
        'Unavailable feed cannot produce a snapshot.',
      ),
    };
  }

  ScenarioLocalTimeDraft _localTime(ScenarioTransitTime value) {
    final secondsWithinDay =
        value.secondsFromServiceDay % Duration.secondsPerDay;
    return ScenarioLocalTimeDraft(
      hour: secondsWithinDay ~/ Duration.secondsPerHour,
      minute:
          (secondsWithinDay % Duration.secondsPerHour) ~/
          Duration.secondsPerMinute,
    );
  }

  ScenarioPlannedTransportKind _transportKind(ScenarioTransitMode value) {
    return switch (value) {
      ScenarioTransitMode.bus => ScenarioPlannedTransportKind.bus,
      ScenarioTransitMode.train => ScenarioPlannedTransportKind.train,
      ScenarioTransitMode.tram => ScenarioPlannedTransportKind.tram,
      ScenarioTransitMode.trolleybus => ScenarioPlannedTransportKind.trolleybus,
      ScenarioTransitMode.other => ScenarioPlannedTransportKind.other,
    };
  }

  String? _nullableTrimmed(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
