import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/features/discover/application/queries/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/presentation/pages/discover_map_page.dart';

void main() {
  test('map create route carries current map conditions into create seed', () {
    final DiscoverQuery query = DiscoverQuery.defaults().copyWith(
      queryText: 'museum',
      selectedCategoryIds: const <String>['art'],
      budgetMax: 10,
      radiusMeters: 7500,
      centerLat: 56.501234,
      centerLng: 27.345678,
      marketCityId: 'rezekne',
      manualAreaSelected: true,
      dateFrom: DateTime.parse('2026-04-20T12:00:00Z'),
    );

    final Uri uri = Uri.parse(mapCreateLocationForQuery(query));

    expect(uri.path, RouteNames.create);
    expect(uri.queryParameters['source'], 'map');
    expect(uri.queryParameters['type'], 'event');
    expect(uri.queryParameters['title'], 'Museum idea');
    expect(uri.queryParameters['subtitle'], 'Map area · art · under 10 · 8 km');
    expect(uri.queryParameters['q'], 'museum');
    expect(uri.queryParameters['category'], 'art');
    expect(uri.queryParameters['free'], '0');
    expect(uri.queryParameters['budgetMax'], '10');
    expect(uri.queryParameters['radius'], '7500');
    expect(uri.queryParameters['unlimited'], '0');
    expect(uri.queryParameters['city'], 'Rezekne');
    expect(uri.queryParameters['itemLat'], '56.501234');
    expect(uri.queryParameters['itemLng'], '27.345678');
    expect(uri.queryParameters['dateFrom'], '2026-04-20T12:00:00.000Z');
  });

  test('map saved search route helpers carry intent context', () {
    final SavedSearchEntity search = SavedSearchEntity(
      id: 'search_museum',
      title: 'Museum ideas',
      subtitle: 'Art · up to 10 · 5 km',
      query: DiscoverQuery.defaults().copyWith(
        queryText: 'museum',
        selectedCategoryIds: const <String>['art'],
        budgetMax: 10,
        radiusMeters: 5000,
      ),
      createdAtUtc: DateTime.parse('2026-04-21T08:00:00Z'),
    );

    final Uri createUri = Uri.parse(mapCreateLocationForSavedSearch(search));
    final Uri routeUri = Uri.parse(
      mapScenarioBuilderLocationForQuery(search.query),
    );

    expect(createUri.path, RouteNames.create);
    expect(createUri.queryParameters['source'], 'saved_search');
    expect(createUri.queryParameters['title'], 'Museum ideas');
    expect(createUri.queryParameters['q'], 'museum');
    expect(createUri.queryParameters['category'], 'art');
    expect(createUri.queryParameters['budgetMax'], '10');
    expect(routeUri.path, RouteNames.scenarioBuilder);
    expect(routeUri.queryParameters['mood'], 'social');
    expect(routeUri.queryParameters['prompt'], contains('museum'));
  });

  test('map smart search route helpers preserve prompt context', () {
    final SmartSearchHistoryEntity item = SmartSearchHistoryEntity(
      id: 'smart_museum',
      prompt: 'museum today under 10',
      query: DiscoverQuery.defaults().copyWith(
        queryText: 'museum',
        selectedCategoryIds: const <String>['art'],
        budgetMax: 10,
        radiusMeters: 5000,
      ),
      createdAtUtc: DateTime.parse('2026-04-22T08:00:00Z'),
    );

    final Uri createUri = Uri.parse(mapCreateLocationForSmartSearch(item));
    final Uri routeUri = Uri.parse(
      mapScenarioBuilderLocationForSmartSearch(item),
    );

    expect(createUri.path, RouteNames.create);
    expect(createUri.queryParameters['source'], 'smart_search');
    expect(createUri.queryParameters['title'], 'Museum');
    expect(createUri.queryParameters['subtitle'], 'museum today under 10');
    expect(createUri.queryParameters['category'], 'art');
    expect(createUri.queryParameters['budgetMax'], '10');
    expect(routeUri.path, RouteNames.scenarioBuilder);
    expect(routeUri.queryParameters['mood'], 'social');
    expect(routeUri.queryParameters['prompt'], 'museum today under 10');
  });

  test('map smart route helpers preserve structured route intent', () {
    final SmartSearchHistoryEntity item = SmartSearchHistoryEntity(
      id: 'smart_route',
      prompt:
          'build a free calm walking route for 2 hours with coffee and park near 5 km',
      query: DiscoverQuery.defaults().copyWith(
        queryText: 'route',
        freeOnly: true,
        selectedCategoryIds: const <String>['wellness'],
        radiusMeters: 5000,
      ),
      createdAtUtc: DateTime.parse('2026-04-23T08:00:00Z'),
    );

    final Uri createUri = Uri.parse(mapCreateLocationForSmartSearch(item));
    final Uri builderUri = Uri.parse(
      mapScenarioBuilderLocationForSmartSearch(item),
    );

    expect(createUri.path, RouteNames.create);
    expect(createUri.queryParameters['source'], 'scenario');
    expect(createUri.queryParameters['title'], 'Calm recharge route');
    expect(createUri.queryParameters['q'], item.prompt);
    expect(createUri.queryParameters['category'], 'scenario');
    expect(createUri.queryParameters['duration'], '120');
    expect(createUri.queryParameters['free'], '1');
    expect(
      createUri.queryParameters['steps'],
      'food_drinks.coffee,wellness_recharge.calm_walk',
    );

    expect(builderUri.path, RouteNames.scenarioBuilder);
    expect(builderUri.queryParameters['mood'], 'calm');
    expect(builderUri.queryParameters['duration'], '120');
    expect(builderUri.queryParameters['free'], '1');
    expect(builderUri.queryParameters['walking'], '1');
    expect(builderUri.queryParameters['prompt'], item.prompt);
    expect(
      builderUri.queryParameters['steps'],
      'food_drinks.coffee,wellness_recharge.calm_walk',
    );
  });

  test('map scenario route action helpers preserve route context', () {
    final Map<String, String> seed = <String, String>{
      'mode': 'scenario',
      'mood': 'social',
      'duration': '150',
      'free': '0',
      'walking': '1',
      'prompt': 'social evening near me',
      'steps': 'games_indoor.board_games,music_nightlife.afterwork_drinks',
    };

    final Uri builderUri = Uri.parse(mapScenarioBuilderLocationForSeed(seed)!);
    final Uri createUri = Uri.parse(mapScenarioCreateLocationForSeed(seed)!);
    final Uri searchUri = Uri.parse(mapScenarioSearchLocationForSeed(seed)!);

    expect(builderUri.path, RouteNames.scenarioBuilder);
    expect(builderUri.queryParameters['mode'], isNull);
    expect(builderUri.queryParameters['mood'], 'social');
    expect(builderUri.queryParameters['duration'], '150');
    expect(builderUri.queryParameters['prompt'], 'social evening near me');
    expect(
      builderUri.queryParameters['steps'],
      'games_indoor.board_games,music_nightlife.afterwork_drinks',
    );

    expect(createUri.path, RouteNames.create);
    expect(createUri.queryParameters['source'], 'scenario');
    expect(createUri.queryParameters['type'], 'event');
    expect(createUri.queryParameters['title'], 'Social recharge route');
    expect(createUri.queryParameters['q'], 'social evening near me');
    expect(createUri.queryParameters['category'], 'scenario');
    expect(createUri.queryParameters['walking'], '1');
    expect(
      createUri.queryParameters['steps'],
      'games_indoor.board_games,music_nightlife.afterwork_drinks',
    );

    expect(searchUri.path, RouteNames.search);
    expect(searchUri.queryParameters['q'], 'social evening near me');
    expect(searchUri.queryParameters['category'], 'music_nightlife');
    expect(searchUri.queryParameters['free'], '0');
    expect(searchUri.queryParameters['radius'], '5000');
  });

  test('map scenario route action helpers ignore invalid seed', () {
    final Map<String, String> seed = <String, String>{
      'mode': 'scenario',
      'mood': 'calm',
    };

    expect(mapScenarioBuilderLocationForSeed(seed), isNull);
    expect(mapScenarioCreateLocationForSeed(seed), isNull);
    expect(mapScenarioSearchLocationForSeed(seed), isNull);
  });
}
