import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';
import 'package:recharge/features/create/domain/usecases/build_scenario_transit_snapshot_usecase.dart';

void main() {
  const subject = BuildScenarioTransitSnapshotUseCase();

  test(
    'builds an autonomous exact snapshot across the service-day boundary',
    () {
      final result = subject(
        _option(
          departureSeconds: 23 * 3600 + 59 * 60 + 30,
          arrivalSeconds: 24 * 3600 + 31,
        ),
      );
      final snapshot = result.snapshot;

      expect(result.source.kind, ScenarioPlannedTransportKind.train);
      expect(result.durationMinutes, 2);
      expect(snapshot.providerCode, 'lv_vivi_train');
      expect(snapshot.providerDisplayName, 'Vivi');
      expect(snapshot.licenseName, 'CC0 1.0');
      expect(snapshot.tripId, 'trip-42');
      expect(snapshot.routeId, 'route-riga-valga');
      expect(snapshot.serviceId, 'weekday');
      expect(snapshot.originStopId, 'riga');
      expect(snapshot.destinationStopId, 'sigulda');
      expect(snapshot.feedSha256, 'a' * 64);
      expect(snapshot.serviceDate?.iso8601, '2026-08-03');
      expect(snapshot.plannedDeparture?.hhmm, '23:59');
      expect(snapshot.plannedArrival?.hhmm, '00:00');
      expect(snapshot.departureSecondsFromServiceDay, 86370);
      expect(snapshot.arrivalSecondsFromServiceDay, 86431);
      expect(snapshot.departureDayOffset, 0);
      expect(snapshot.arrivalDayOffset, 1);
      expect(snapshot.freshness, ScenarioScheduleFreshness.current);
      expect(snapshot.retrievedAtUtc, DateTime.utc(2026, 8, 3, 7));
      expect(snapshot.sourceUrl, 'https://vivi.lv/uploads/GTFS.zip');
    },
  );

  test('maps stale and unknown freshness without inventing current data', () {
    expect(
      subject(
        _option(freshness: ScenarioTransitFreshness.stale),
      ).snapshot.freshness,
      ScenarioScheduleFreshness.stale,
    );
    expect(
      subject(
        _option(freshness: ScenarioTransitFreshness.unknown),
      ).snapshot.freshness,
      ScenarioScheduleFreshness.unknown,
    );
  });

  test('rejects malformed provenance before producing a snapshot', () {
    expect(
      () => subject(_option(manifestProviderCode: 'another-provider')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => subject(_option(sha256: 'not-a-digest')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => subject(_option(freshness: ScenarioTransitFreshness.unavailable)),
      throwsA(isA<FormatException>()),
    );
  });
}

ScenarioTransitServiceOption _option({
  int departureSeconds = 8 * 3600,
  int arrivalSeconds = 9 * 3600,
  ScenarioTransitFreshness freshness = ScenarioTransitFreshness.current,
  String manifestProviderCode = 'lv_vivi_train',
  String sha256 = '',
}) {
  const providerCode = 'lv_vivi_train';
  return ScenarioTransitServiceOption(
    providerCode: providerCode,
    serviceDate: const ScenarioTransitLocalDate(2026, 8, 3),
    tripId: 'trip-42',
    routeId: 'route-riga-valga',
    serviceId: 'weekday',
    mode: ScenarioTransitMode.train,
    origin: const ScenarioTransitStop(
      providerCode: providerCode,
      id: 'riga',
      name: 'Rīga',
    ),
    destination: const ScenarioTransitStop(
      providerCode: providerCode,
      id: 'sigulda',
      name: 'Sigulda',
    ),
    departure: ScenarioTransitTime(departureSeconds),
    arrival: ScenarioTransitTime(arrivalSeconds),
    manifest: ScenarioTransitFeedManifest(
      providerCode: manifestProviderCode,
      providerDisplayName: 'Vivi',
      licenseName: 'CC0 1.0',
      sourceUrl: 'https://vivi.lv/uploads/GTFS.zip',
      retrievedAtUtc: DateTime.utc(2026, 8, 3, 7),
      sha256: sha256.isEmpty ? 'a' * 64 : sha256,
      freshness: freshness,
    ),
    agencyName: 'Vivi',
    routeLabel: 'Rīga–Valga',
    headsign: 'Valga',
  );
}
