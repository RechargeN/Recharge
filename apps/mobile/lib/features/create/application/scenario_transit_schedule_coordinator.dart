import '../domain/entities/scenario_transit_schedule.dart';
import '../domain/repositories/scenario_transit_schedule_repository.dart';
import '../domain/usecases/search_scenario_transit_options_usecase.dart';

class ScenarioTransitScheduleCoordinator {
  ScenarioTransitScheduleCoordinator({
    required ScenarioTransitScheduleRepository repository,
  }) : _repository = repository,
       _search = SearchScenarioTransitOptionsUseCase(repository);

  final ScenarioTransitScheduleRepository _repository;
  final SearchScenarioTransitOptionsUseCase _search;

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
}
