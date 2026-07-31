import '../entities/scenario_transit_schedule.dart';

abstract class ScenarioTransitScheduleRepository {
  Future<ScenarioTransitFeedManifest> refreshProvider(String providerCode);

  Future<ScenarioTransitFeedManifest?> loadLastKnownGood(String providerCode);

  Future<List<ScenarioTransitStop>> searchStops({
    required String query,
    Set<String> providerCodes = const <String>{},
    int limit = 20,
  });

  Future<ScenarioTransitSearchResult> searchServices(
    ScenarioTransitSearchQuery query,
  );
}
