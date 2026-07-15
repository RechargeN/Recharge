import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/discover_providers.dart';
import 'package:recharge/features/discover/application/queries/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/discover/presentation/pages/discover_results_page.dart';

import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets('renders search controls and results', (tester) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Search Recharge'), findsOneWidget);
    expect(find.text('Quick scenarios'), findsOneWidget);
    expect(find.text('Conditions'), findsOneWidget);
    expect(find.text('Утренняя йога'), findsOneWidget);
  });

  fullPageTestWidgets('category chip filters results', (tester) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Outdoor'));
    await tester.pumpAndSettle();

    expect(find.text('Прогулка у озера'), findsOneWidget);
    expect(find.text('Утренняя йога'), findsNothing);
  });

  fullPageTestWidgets('smart search parses text into filters', (tester) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'museum today under 10',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    expect(find.text('Museum today'), findsOneWidget);
    expect(find.text('Утренняя йога'), findsNothing);
    expect(find.text('"museum"'), findsOneWidget);
    expect(find.text('up to 10'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);

    await tester.tap(find.text('Build scenario'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
  });

  fullPageTestWidgets('smart search route intent opens builder map and create', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'build a free calm walking route for 2 hours with coffee and park near 5 km',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    expect(find.text('Smart route'), findsWidgets);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120 min'), findsWidgets);
    expect(find.text('free route'), findsOneWidget);
    expect(find.text('walking'), findsOneWidget);
    expect(find.textContaining('Coffee'), findsOneWidget);

    await tester.tap(find.text('Build route'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);

    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'build a free calm walking route for 2 hours with coffee and park near 5 km',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map route'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);

    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'build a free calm walking route for 2 hours with coffee and park near 5 km',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create smart route listing'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('scenario'), findsWidgets);
    expect(find.text('Calm recharge route'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
  });

  fullPageTestWidgets('opens map with applied search conditions', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'museum today under 10',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Map'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
  });

  fullPageTestWidgets('opens create from active search conditions', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'museum today under 10',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create from current search'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('search'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
  });

  fullPageTestWidgets('stores recent smart search and opens create from it', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'museum today under 10',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    expect(find.text('Recent Smart Searches'), findsOneWidget);
    expect(find.text('museum today under 10'), findsWidgets);

    await tester.ensureVisible(
      find.byTooltip('Create listing from smart search'),
    );
    await tester.tap(find.byTooltip('Create listing from smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('smart_search'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
  });

  fullPageTestWidgets('keeps smart route intent in recent smart search actions', (
    tester,
  ) async {
    final _SearchTestApp app = _SearchTestApp();
    const String prompt =
        'build a free calm walking route for 2 hours with coffee and park near 5 km';

    await tester.pumpWidget(_SearchTestApp(controller: app._controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, prompt);
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    expect(find.text('Recent Smart Searches'), findsOneWidget);
    expect(find.text('Smart route'), findsWidgets);

    await tester.ensureVisible(
      find.byTooltip('Build route from smart search').last,
    );
    await tester.tap(find.byTooltip('Build route from smart search').last);
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);

    await tester.pumpWidget(_SearchTestApp(controller: app._controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Open smart search on map').last);
    await tester.tap(find.byTooltip('Open smart search on map').last);
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);

    await tester.pumpWidget(_SearchTestApp(controller: app._controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byTooltip('Create listing from smart search'),
    );
    await tester.tap(find.byTooltip('Create listing from smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('scenario'), findsWidgets);
    expect(find.text('Calm recharge route'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
  });

  fullPageTestWidgets('applies route seed parameters on open', (tester) async {
    await tester.pumpWidget(
      _SearchTestApp(
        initialLocation:
            '${RouteNames.search}?q=Museum%20today&category=art&free=0&radius=5000',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Museum today'), findsWidgets);
    expect(find.text('Утренняя йога'), findsNothing);
    expect(find.text('Прогулка у озера'), findsNothing);
    expect(find.text('Art'), findsOneWidget);
  });

  fullPageTestWidgets('saves applies routes and deletes search conditions', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'museum today under 10',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Museum'), findsOneWidget);
    expect(find.textContaining('up to 10'), findsWidgets);

    await tester.tap(find.byTooltip('Delete saved conditions'));
    await tester.pumpAndSettle();
    expect(find.text('No saved conditions yet'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Museum'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open saved conditions on map'));
    await tester.pumpAndSettle();
    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  fullPageTestWidgets('opens scenario builder from saved conditions', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'free yoga near 5 km');
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byTooltip('Build route from saved conditions'),
    );
    await tester.tap(find.byTooltip('Build route from saved conditions'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
  });

  fullPageTestWidgets('opens create from saved conditions', (tester) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'museum today under 10',
    );
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byTooltip('Create listing from saved conditions'),
    );
    await tester.tap(find.byTooltip('Create listing from saved conditions'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('saved_search'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });
}

class _SearchTestApp extends StatelessWidget {
  _SearchTestApp({
    this.initialLocation = RouteNames.search,
    DiscoverFeedController? controller,
  }) : _controller =
           controller ??
           DiscoverFeedController(
             getDiscoverFeedUseCase: GetDiscoverFeedUseCase(
               _FakeDiscoverRepository(),
             ),
             discoverPreferencesRepository:
                 _FakeDiscoverPreferencesRepository(),
             analyticsService: _NoopAnalyticsService(),
           );

  final String initialLocation;

  final DiscoverFeedController _controller;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        discoverFeedControllerProvider.overrideWith((ref) => _controller),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.search,
              builder: (context, state) => DiscoverResultsPage(
                seedParameters: state.uri.queryParameters,
              ),
            ),
            GoRoute(
              path: RouteNames.discoverMap,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Column(
                    children: <Widget>[
                      const Text('Map page'),
                      Text(state.uri.queryParameters['mode'] ?? ''),
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(state.uri.queryParameters['duration'] ?? ''),
                      Text(state.uri.queryParameters['q'] ?? ''),
                      Text(state.uri.queryParameters['category'] ?? ''),
                      Text(state.uri.queryParameters['free'] ?? ''),
                      Text(state.uri.queryParameters['budgetMax'] ?? ''),
                      Text(state.uri.queryParameters['radius'] ?? ''),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                    ],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: RouteNames.scenarioBuilder,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Column(
                    children: <Widget>[
                      const Text('Builder page'),
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(state.uri.queryParameters['duration'] ?? ''),
                      Text(state.uri.queryParameters['free'] ?? ''),
                      Text(state.uri.queryParameters['walking'] ?? ''),
                      Text(state.uri.queryParameters['prompt'] ?? ''),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                    ],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: RouteNames.create,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Column(
                    children: <Widget>[
                      const Text('Create page'),
                      Text(state.uri.queryParameters['source'] ?? ''),
                      Text(state.uri.queryParameters['title'] ?? ''),
                      Text(state.uri.queryParameters['q'] ?? ''),
                      Text(state.uri.queryParameters['category'] ?? ''),
                      Text(state.uri.queryParameters['budgetMax'] ?? ''),
                      Text(state.uri.queryParameters['type'] ?? ''),
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(state.uri.queryParameters['duration'] ?? ''),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                    ],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '${RouteNames.discoverDetails}/:itemId',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Details page'))),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeDiscoverRepository implements DiscoverRepository {
  final List<DiscoverItemEntity> _items = <DiscoverItemEntity>[
    DiscoverItemEntity(
      id: 'evt_1',
      title: 'Утренняя йога',
      subtitle: 'Легкая практика',
      city: 'Резекне',
      category: 'wellness',
      startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
      latitude: 56.5099,
      longitude: 27.3332,
      priceAmount: 0,
      distanceKm: 1.2,
      isFree: true,
      relevanceScore: 0.8,
    ),
    DiscoverItemEntity(
      id: 'evt_2',
      title: 'Прогулка у озера',
      subtitle: 'Маршрут 5 км',
      city: 'Резекне',
      category: 'outdoor',
      startsAtUtc: DateTime.parse('2026-04-18T10:00:00Z'),
      latitude: 56.51,
      longitude: 27.34,
      priceAmount: 0,
      distanceKm: 1.8,
      isFree: true,
      relevanceScore: 0.7,
    ),
    DiscoverItemEntity(
      id: 'evt_3',
      title: 'Museum today',
      subtitle: 'Guided visit',
      city: 'Резекне',
      category: 'art',
      startsAtUtc: DateTime.parse('2026-04-18T12:00:00Z'),
      latitude: 56.51,
      longitude: 27.34,
      priceAmount: 8,
      distanceKm: 1.4,
      isFree: false,
      relevanceScore: 0.75,
    ),
  ];

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) async {
    return _items.firstWhere((DiscoverItemEntity item) => item.id == itemId);
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    return _items
        .where((DiscoverItemEntity item) {
          if (query.selectedCategoryIds.isNotEmpty &&
              !query.selectedCategoryIds.contains(item.category)) {
            return false;
          }
          if (query.queryText.isNotEmpty &&
              !item.title.toLowerCase().contains(
                query.queryText.toLowerCase(),
              )) {
            return false;
          }
          if (query.freeOnly && !item.isFree) return false;
          if (query.budgetMax != null && item.priceAmount > query.budgetMax!) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}

class _FakeDiscoverPreferencesRepository
    implements DiscoverPreferencesRepository {
  DiscoverQuery? _savedQuery;
  final List<SavedSearchEntity> _savedSearches = <SavedSearchEntity>[];
  final List<SmartSearchHistoryEntity> _smartSearchHistory =
      <SmartSearchHistoryEntity>[];

  @override
  Future<DiscoverQuery?> loadLastQuery() async => _savedQuery;

  @override
  Future<void> saveLastQuery(DiscoverQuery query) async {
    _savedQuery = query;
  }

  @override
  Future<List<SavedSearchEntity>> loadSavedSearches() async {
    return List<SavedSearchEntity>.of(_savedSearches);
  }

  @override
  Future<void> saveSavedSearch(SavedSearchEntity search) async {
    _savedSearches.removeWhere(
      (SavedSearchEntity item) => item.id == search.id,
    );
    _savedSearches.insert(0, search);
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    _savedSearches.removeWhere((SavedSearchEntity item) => item.id == id);
  }

  @override
  Future<List<SmartSearchHistoryEntity>> loadSmartSearchHistory() async {
    return List<SmartSearchHistoryEntity>.of(_smartSearchHistory);
  }

  @override
  Future<void> saveSmartSearchPrompt(SmartSearchHistoryEntity item) async {
    _smartSearchHistory.removeWhere(
      (SmartSearchHistoryEntity current) => current.id == item.id,
    );
    _smartSearchHistory.insert(0, item);
  }

  @override
  Future<void> deleteSmartSearchPrompt(String id) async {
    _smartSearchHistory.removeWhere(
      (SmartSearchHistoryEntity item) => item.id == id,
    );
  }
}
