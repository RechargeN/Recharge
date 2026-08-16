import '../domain/entities/scenario_transit_schedule.dart';
import '../domain/entities/scenario_item_draft.dart';
import '../domain/entities/scenario_transit_mutation.dart';
import '../domain/repositories/scenario_transit_schedule_repository.dart';
import '../domain/usecases/search_scenario_transit_options_usecase.dart';
import '../domain/usecases/recheck_scenario_transit_snapshot_usecase.dart';

class ScenarioTransitScheduleCoordinator {
  ScenarioTransitScheduleCoordinator({
    required ScenarioTransitScheduleRepository repository,
  }) : _repository = repository,
       _search = SearchScenarioTransitOptionsUseCase(repository),
       _recheck = RecheckScenarioTransitSnapshotUseCase(repository: repository);

  final ScenarioTransitScheduleRepository _repository;
  final SearchScenarioTransitOptionsUseCase _search;
  final RecheckScenarioTransitSnapshotUseCase _recheck;

  List<ScenarioTransitProviderDescriptor> get providers =>
      _repository.providers;

  Future<Map<String, ScenarioTransitCacheInspection>> inspectCached(
    Iterable<String> providerCodes,
  ) async {
    final entries = await Future.wait(
      providerCodes.map((code) async {
        final inspection = await _repository.inspectCache(code);
        return MapEntry<String, ScenarioTransitCacheInspection>(
          code,
          inspection,
        );
      }),
    );
    return Map<String, ScenarioTransitCacheInspection>.unmodifiable(
      Map<String, ScenarioTransitCacheInspection>.fromEntries(entries),
    );
  }

  Future<Map<String, ScenarioTransitFeedManifest?>> loadCached(
    Iterable<String> providerCodes,
  ) async {
    final result = <String, ScenarioTransitFeedManifest?>{};
    for (final code in providerCodes) {
      result[code] = await _repository.loadLastKnownGood(code);
    }
    return Map<String, ScenarioTransitFeedManifest?>.unmodifiable(result);
  }

  Future<ScenarioTransitFeedManifest> refresh(String providerCode) =>
      _repository.refreshProvider(providerCode);

  Future<List<ScenarioTransitStop>> searchStops({
    required String query,
    Set<String> providerCodes = const <String>{},
    int limit = 20,
  }) => _repository.searchStops(
    query: query,
    providerCodes: providerCodes,
    limit: limit,
  );

  Future<ScenarioTransitSearchResult> search(
    ScenarioTransitSearchQuery query,
  ) => _search(query);

  Future<ScenarioTransitRecheckResult> recheck(
    ScenarioScheduleSnapshotDraft snapshot,
  ) => _recheck(snapshot);
}
