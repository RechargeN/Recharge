import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/discover_providers.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/discover/presentation/pages/discover_results_page.dart';
import 'package:recharge/features/discover/presentation/pages/search_page.dart';

import 'widget_test_viewport.dart';

void main() {
  testWidgets('filter sheets preserve reference metrics on a 360dp phone', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 720)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(_SearchLandingTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('regular-search-filters')));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('search-filters-sheet'))).width,
      360,
    );
    expect(
      tester.getSize(find.byKey(const Key('filter-apply-button'))).height,
      40,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Exact'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('filter-start-time'))).height,
      44,
    );
    expect(tester.getSize(find.byKey(const Key('filter-end-time'))).height, 44);
    expect(tester.takeException(), isNull);
  });

  fullPageTestWidgets('renders the separate regular search landing', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchLandingTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Search Recharge'), findsOneWidget);
    expect(find.text('Near me now'), findsOneWidget);
    expect(find.text('For two'), findsOneWidget);
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Smart Search'), findsNothing);

    await tester.tap(find.text('For two'));
    await tester.pump();
    expect(find.text('2 people'), findsOneWidget);
  });

  fullPageTestWidgets('regular search landing hands conditions to results', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchLandingTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('regular-search-field')),
      'museum',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Results destination'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('regular_search'), findsOneWidget);
  });

  fullPageTestWidgets('regular search exposes time-fit and travel controls', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchLandingTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('regular-search-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Exact'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('filter-apply-button'))).height,
      40,
    );
    await tester.tap(find.text('Exact'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-start-time')), findsOneWidget);
    expect(find.byKey(const Key('filter-end-time')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Include return trip'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byTooltip('Walking'), findsOneWidget);
    expect(find.text("I'm here"), findsOneWidget);
    expect(find.text('Include return trip'), findsOneWidget);
  });

  fullPageTestWidgets('accepts custom people and budget values', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchLandingTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('regular-search-filters')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('people-custom')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('people-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom-number-input')), '7');
    await tester.tap(find.byKey(const Key('custom-number-save')));
    await tester.pumpAndSettle();
    expect(find.text('Custom · 7'), findsOneWidget);

    expect(find.text('€0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('budget-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom-number-input')), '35');
    await tester.tap(find.byKey(const Key('custom-number-save')));
    await tester.pumpAndSettle();
    expect(find.text('Custom · €35'), findsOneWidget);
  });

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

    final Finder outdoorChip = find.widgetWithText(
      ChoiceChip,
      'Outdoor, nature & walking',
    );
    await tester.scrollUntilVisible(
      outdoorChip,
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('discover-category-rail')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(outdoorChip);
    await tester.pumpAndSettle();
    await tester.tap(outdoorChip);
    await tester.pumpAndSettle();

    expect(find.text('Прогулка у озера'), findsOneWidget);
    expect(find.text('Утренняя йога'), findsNothing);
  });

  fullPageTestWidgets('keeps Smart Search controls out of regular search', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Smart Search'), findsNothing);
    expect(find.text('Parse'), findsNothing);
    expect(find.byTooltip('Voice prompt'), findsNothing);
    expect(find.byTooltip('Search conditions'), findsOneWidget);
  });

  fullPageTestWidgets('regular search treats text as a literal query', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'museum today under 10',
    );
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Applied: "museum today under 10"'),
      findsOneWidget,
    );
    expect(find.text('up to 10'), findsNothing);
  });

  fullPageTestWidgets('opens map with applied search conditions', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'museum');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Map'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
  });

  fullPageTestWidgets('opens create from active search conditions', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'museum');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create from current search'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('search'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
  });

  fullPageTestWidgets('does not load or render Smart Search history', (
    tester,
  ) async {
    await tester.pumpWidget(_SearchTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Recent Smart Searches'), findsNothing);
    expect(find.byTooltip('Create listing from smart search'), findsNothing);
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
    final Finder artChip = find.widgetWithText(
      ChoiceChip,
      'Art, culture & museums',
    );
    await tester.scrollUntilVisible(
      artChip,
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('discover-category-rail')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(artChip, findsOneWidget);
  });

  fullPageTestWidgets('saves applies routes and deletes search conditions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SearchTestApp(
        initialLocation:
            '${RouteNames.search}?q=museum&category=art&budgetMax=10&radius=5000',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Museum'), findsOneWidget);
    expect(find.textContaining('up to 10'), findsWidgets);

    await tester.tap(find.byTooltip('Delete saved conditions'));
    await tester.pumpAndSettle();
    expect(find.text('No recent searches yet'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Museum'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open saved conditions on map'));
    await tester.pumpAndSettle();
    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art_culture_museums'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  fullPageTestWidgets('opens scenario builder from saved conditions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SearchTestApp(
        initialLocation:
            '${RouteNames.search}?q=free%20yoga&free=1&radius=5000',
      ),
    );
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
    await tester.pumpWidget(
      _SearchTestApp(
        initialLocation:
            '${RouteNames.search}?q=museum&category=art&budgetMax=10&radius=5000',
      ),
    );
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
    expect(find.text('art_culture_museums'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  fullPageTestWidgets(
    'records a regular query in recent searches automatically',
    (tester) async {
      await tester.pumpWidget(
        _SearchTestApp(
          initialLocation:
              '${RouteNames.search}?source=regular_search&q=museum&radius=5000',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Museum'), findsOneWidget);
      expect(find.textContaining('5 km'), findsWidgets);
    },
  );
}

class _SearchLandingTestApp extends StatelessWidget {
  _SearchLandingTestApp()
    : _controller = DiscoverFeedController(
        getDiscoverFeedUseCase: GetDiscoverFeedUseCase(
          _FakeDiscoverRepository(),
        ),
        discoverPreferencesRepository: _FakeDiscoverPreferencesRepository(),
        analyticsService: _NoopAnalyticsService(),
      );

  final DiscoverFeedController _controller;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        discoverFeedControllerProvider.overrideWith((ref) => _controller),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: RouteNames.search,
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.search,
              builder: (context, state) => const SearchPage(),
            ),
            GoRoute(
              path: RouteNames.discoverResults,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Results destination'),
                      Text(state.uri.queryParameters['q'] ?? ''),
                      Text(state.uri.queryParameters['source'] ?? ''),
                    ],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: RouteNames.scenarioBuilder,
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
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
      category: 'wellness_recharge',
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
      category: 'outdoor_nature_walking',
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
      category: 'art_culture_museums',
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
