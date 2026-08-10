import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_mutation.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';
import 'package:recharge/features/create/domain/repositories/scenario_transit_schedule_repository.dart';
import 'package:recharge/features/create/domain/usecases/build_scenario_transit_snapshot_usecase.dart';
import 'package:recharge/features/create/domain/usecases/recheck_scenario_transit_snapshot_usecase.dart';

void main() {
  late _Repository repository;
  late RecheckScenarioTransitSnapshotUseCase recheck;
  late ScenarioScheduleSnapshotDraft snapshot;

  setUp(() {
    repository = _Repository();
    recheck = RecheckScenarioTransitSnapshotUseCase(repository: repository);
    snapshot = BuildScenarioTransitSnapshotUseCase()(_option()).snapshot;
  });

  test('uses exact trip identity and reports unchanged snapshot', () async {
    repository.result = ScenarioTransitSearchResult(
      options: <ScenarioTransitServiceOption>[_option()],
      loadedProviders: const <String>{'provider-a'},
      unavailableProviders: const <String>{},
    );

    final result = await recheck(snapshot);

    expect(result.status, ScenarioTransitRecheckStatus.unchanged);
    expect(repository.lastQuery?.exactTripId, 'trip-1');
    expect(repository.lastQuery?.providerCodes, <String>{'provider-a'});
    expect(repository.lastQuery?.originStopId, 'origin');
    expect(repository.lastQuery?.destinationStopId, 'destination');
  });

  test('returns typed differences without changing the old snapshot', () async {
    repository.result = ScenarioTransitSearchResult(
      options: <ScenarioTransitServiceOption>[
        _option(departure: 11 * 3600, arrival: 12 * 3600, sha: 'b' * 64),
      ],
      loadedProviders: const <String>{'provider-a'},
      unavailableProviders: const <String>{},
    );

    final result = await recheck(snapshot);

    expect(result.status, ScenarioTransitRecheckStatus.changed);
    expect(result.canReplace, isTrue);
    expect(
      result.differences.map((value) => value.fieldCode),
      containsAll(<String>['departure', 'arrival', 'feed_hash']),
    );
    expect(snapshot.departureSecondsFromServiceDay, 10 * 3600);
    expect(snapshot.feedSha256, 'a' * 64);
  });

  test('not found and unavailable never invent a replacement', () async {
    repository.result = const ScenarioTransitSearchResult(
      options: <ScenarioTransitServiceOption>[],
      loadedProviders: <String>{'provider-a'},
      unavailableProviders: <String>{},
    );
    final missing = await recheck(snapshot);
    expect(missing.status, ScenarioTransitRecheckStatus.notFound);
    expect(missing.candidate, isNull);

    repository.result = const ScenarioTransitSearchResult(
      options: <ScenarioTransitServiceOption>[],
      loadedProviders: <String>{},
      unavailableProviders: <String>{'provider-a'},
    );
    final unavailable = await recheck(snapshot);
    expect(unavailable.status, ScenarioTransitRecheckStatus.unavailable);
    expect(unavailable.candidate, isNull);
  });
}

ScenarioTransitServiceOption _option({
  int departure = 10 * 3600,
  int arrival = 11 * 3600,
  String? sha,
}) => ScenarioTransitServiceOption(
  providerCode: 'provider-a',
  serviceDate: const ScenarioTransitLocalDate(2026, 8, 3),
  tripId: 'trip-1',
  routeId: 'route-1',
  serviceId: 'weekday',
  mode: ScenarioTransitMode.train,
  origin: const ScenarioTransitStop(
    providerCode: 'provider-a',
    id: 'origin',
    name: 'Riga Central',
    latitude: 56.9463,
    longitude: 24.1204,
  ),
  destination: const ScenarioTransitStop(
    providerCode: 'provider-a',
    id: 'destination',
    name: 'Sigulda',
    latitude: 57.1537,
    longitude: 24.8538,
  ),
  departure: ScenarioTransitTime(departure),
  arrival: ScenarioTransitTime(arrival),
  manifest: ScenarioTransitFeedManifest(
    providerCode: 'provider-a',
    providerDisplayName: 'Provider A',
    licenseName: 'CC0 1.0',
    sourceUrl: 'https://example.test/a.zip',
    retrievedAtUtc: DateTime.utc(2026, 8, 3, 8),
    sha256: sha ?? 'a' * 64,
    freshness: ScenarioTransitFreshness.current,
  ),
  agencyName: 'Vivi',
  routeLabel: 'Riga–Sigulda',
);

class _Repository implements ScenarioTransitScheduleRepository {
  ScenarioTransitSearchResult result = const ScenarioTransitSearchResult(
    options: <ScenarioTransitServiceOption>[],
    loadedProviders: <String>{},
    unavailableProviders: <String>{},
  );
  ScenarioTransitSearchQuery? lastQuery;

  @override
  List<ScenarioTransitProviderDescriptor> get providers => const [];

  @override
  Future<ScenarioTransitCacheInspection> inspectCache(String providerCode) =>
      throw UnimplementedError();

  @override
  Future<ScenarioTransitFeedManifest?> loadLastKnownGood(String providerCode) =>
      throw UnimplementedError();

  @override
  Future<ScenarioTransitFeedManifest> refreshProvider(String providerCode) =>
      throw UnimplementedError();

  @override
  Future<ScenarioTransitSearchResult> searchServices(
    ScenarioTransitSearchQuery query,
  ) async {
    lastQuery = query;
    return result;
  }

  @override
  Future<List<ScenarioTransitStop>> searchStops({
    required String query,
    Set<String> providerCodes = const <String>{},
    int limit = 20,
  }) => throw UnimplementedError();
}
