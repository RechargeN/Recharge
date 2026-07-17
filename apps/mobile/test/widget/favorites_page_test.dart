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
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'package:recharge/features/favorites/presentation/pages/favorites_page.dart';

import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets('shows empty state when favorites list is empty', (
    tester,
  ) async {
    final controller = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(_FakeFavoritesRepository()),
      addFavoriteUseCase: AddFavoriteUseCase(_FakeFavoritesRepository()),
      removeFavoriteUseCase: RemoveFavoriteUseCase(_FakeFavoritesRepository()),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          favoritesControllerProvider.overrideWith((ref) => controller),
          discoverFeedControllerProvider.overrideWith(
            (ref) => _discoverController(),
          ),
        ],
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пока нет сохраненных событий'), findsOneWidget);
  });

  fullPageTestWidgets('renders favorites item in list', (tester) async {
    final repository = _FakeFavoritesRepository(
      initial: <FavoriteItemEntity>[_favorite('evt_1', 'Утренняя йога')],
    );
    final controller = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(repository),
      addFavoriteUseCase: AddFavoriteUseCase(repository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          favoritesControllerProvider.overrideWith((ref) => controller),
          discoverFeedControllerProvider.overrideWith(
            (ref) => _discoverController(),
          ),
        ],
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Утренняя йога'), findsOneWidget);
  });

  fullPageTestWidgets('type filters show only matching saved plans', (
    tester,
  ) async {
    final repository = _FakeFavoritesRepository(
      initial: <FavoriteItemEntity>[
        _favorite('evt_1', 'Утренняя йога'),
        _favorite('place_1', 'Кофейня', category: 'place'),
        _favorite('route_1', 'Тихий маршрут', category: 'scenario'),
      ],
    );
    final controller = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(repository),
      addFavoriteUseCase: AddFavoriteUseCase(repository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          favoritesControllerProvider.overrideWith((ref) => controller),
          discoverFeedControllerProvider.overrideWith(
            (ref) => _discoverController(),
          ),
        ],
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Утренняя йога'), findsOneWidget);
    expect(find.text('Кофейня'), findsOneWidget);
    expect(find.text('Тихий маршрут'), findsOneWidget);

    await tester.tap(find.text('Places').first);
    await tester.pumpAndSettle();

    expect(find.text('Кофейня'), findsOneWidget);
    expect(find.text('Утренняя йога'), findsNothing);
    expect(find.text('Тихий маршрут'), findsNothing);

    await tester.tap(find.text('Routes').first);
    await tester.pumpAndSettle();

    expect(find.text('Тихий маршрут'), findsOneWidget);
    expect(find.text('Кофейня'), findsNothing);
  });

  fullPageTestWidgets('opens saved scenario in builder', (tester) async {
    final repository = _FakeFavoritesRepository(
      initial: <FavoriteItemEntity>[
        _favorite(
          'scenario_calm',
          'Calm recharge scenario',
          category: 'scenario',
          targetRoute:
              '${RouteNames.scenarioBuilder}?mood=active&steps=sport.tennis',
        ),
      ],
    );
    final controller = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(repository),
      addFavoriteUseCase: AddFavoriteUseCase(repository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          favoritesControllerProvider.overrideWith((ref) => controller),
          discoverFeedControllerProvider.overrideWith(
            (ref) => _discoverController(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.favorites,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.favorites,
                builder: (context, state) => const FavoritesPage(),
              ),
              GoRoute(
                path: RouteNames.scenarioBuilder,
                builder: (context, state) =>
                    const Scaffold(body: Center(child: Text('Builder page'))),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ROUTE'), findsOneWidget);

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
  });

  fullPageTestWidgets('opens saved scenario route on map', (tester) async {
    final repository = _FakeFavoritesRepository(
      initial: <FavoriteItemEntity>[
        _favorite(
          'scenario_calm',
          'Calm recharge scenario',
          category: 'scenario',
          targetRoute:
              '${RouteNames.scenarioBuilder}?mood=calm&steps=food_drinks.coffee',
        ),
      ],
    );
    final controller = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(repository),
      addFavoriteUseCase: AddFavoriteUseCase(repository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          favoritesControllerProvider.overrideWith((ref) => controller),
          discoverFeedControllerProvider.overrideWith(
            (ref) => _discoverController(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.favorites,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.favorites,
                builder: (context, state) => const FavoritesPage(),
              ),
              GoRoute(
                path: RouteNames.discoverMap,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Map page'),
                      Text(state.uri.queryParameters['mode'] ?? ''),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ROUTE'), findsOneWidget);

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('food_drinks.coffee'), findsOneWidget);
  });

  fullPageTestWidgets('opens saved conditions from favorites workspace', (
    tester,
  ) async {
    final FavoritesController controller = _favoritesController();
    final DiscoverFeedController discoverController = _discoverController(
      savedSearches: <SavedSearchEntity>[_savedSearch()],
    );

    Widget app() {
      return _FavoritesRouteTestApp(
        favoritesController: controller,
        discoverController: discoverController,
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Saved intents'), findsOneWidget);
    expect(find.text('Saved conditions'), findsOneWidget);
    expect(find.text('Museum ideas'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Search page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map').last);
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Build route from saved conditions'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('social'), findsOneWidget);
    expect(find.textContaining('museum'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create listing from saved conditions'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('saved_search'), findsOneWidget);
    expect(find.text('Museum ideas'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete saved conditions'));
    await tester.pumpAndSettle();

    expect(find.text('Saved conditions'), findsNothing);
  });

  fullPageTestWidgets('opens smart search from favorites workspace', (
    tester,
  ) async {
    final FavoritesController controller = _favoritesController();
    final DiscoverFeedController discoverController = _discoverController(
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
    );

    Widget app() {
      return _FavoritesRouteTestApp(
        favoritesController: controller,
        discoverController: discoverController,
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Saved intents'), findsOneWidget);
    expect(find.text('Smart search'), findsOneWidget);
    expect(find.text('museum today under 10'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Smart Search page'), findsOneWidget);
    expect(find.text('museum today under 10'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map').last);
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Build route from smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('social'), findsOneWidget);
    expect(find.text('museum today under 10'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create listing from smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('smart_search'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Smart search'), findsNothing);
  });

  fullPageTestWidgets('keeps smart route intent from favorites workspace', (
    tester,
  ) async {
    final FavoritesController controller = _favoritesController();
    final DiscoverFeedController discoverController = _discoverController(
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartRouteSearch()],
    );

    Widget app() {
      return _FavoritesRouteTestApp(
        favoritesController: controller,
        discoverController: discoverController,
      );
    }

    const String prompt =
        'build a free calm walking route for 2 hours with coffee and park near 5 km';

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Saved intents'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);
    expect(find.text('Smart route'), findsOneWidget);
    expect(find.text('120 min'), findsOneWidget);
    expect(find.text('2 stops'), findsOneWidget);

    await tester.tap(find.byTooltip('Build route from smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map').last);
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create listing from smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('scenario'), findsWidgets);
    expect(find.text('Calm recharge route'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
  });
}

class _FavoritesRouteTestApp extends StatelessWidget {
  const _FavoritesRouteTestApp({
    required this.favoritesController,
    required this.discoverController,
  });

  final FavoritesController favoritesController;
  final DiscoverFeedController discoverController;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        favoritesControllerProvider.overrideWith((ref) => favoritesController),
        discoverFeedControllerProvider.overrideWith(
          (ref) => discoverController,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: RouteNames.favorites,
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.favorites,
              builder: (context, state) => const FavoritesPage(),
            ),
            GoRoute(
              path: RouteNames.search,
              builder: (context, state) => Scaffold(
                body: Column(
                  children: <Widget>[
                    const Text('Search page'),
                    Text(state.uri.queryParameters['q'] ?? ''),
                    Text(state.uri.queryParameters['category'] ?? ''),
                    Text(state.uri.queryParameters['budgetMax'] ?? ''),
                    Text(state.uri.queryParameters['radius'] ?? ''),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: RouteNames.smartSearch,
              builder: (context, state) => Scaffold(
                body: Column(
                  children: <Widget>[
                    const Text('Smart Search page'),
                    Text(state.uri.queryParameters['prompt'] ?? ''),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: RouteNames.discoverMap,
              builder: (context, state) => Scaffold(
                body: Column(
                  children: <Widget>[
                    const Text('Map page'),
                    Text(state.uri.queryParameters['mode'] ?? ''),
                    Text(state.uri.queryParameters['steps'] ?? ''),
                    Text(state.uri.queryParameters['q'] ?? ''),
                    Text(state.uri.queryParameters['category'] ?? ''),
                    Text(state.uri.queryParameters['budgetMax'] ?? ''),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: RouteNames.scenarioBuilder,
              builder: (context, state) => Scaffold(
                body: Column(
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
            GoRoute(
              path: RouteNames.create,
              builder: (context, state) => Scaffold(
                body: Column(
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
          ],
        ),
      ),
    );
  }
}

FavoritesController _favoritesController({List<FavoriteItemEntity>? initial}) {
  final _FakeFavoritesRepository repository = _FakeFavoritesRepository(
    initial: initial,
  );
  return FavoritesController(
    getFavoritesUseCase: GetFavoritesUseCase(repository),
    addFavoriteUseCase: AddFavoriteUseCase(repository),
    removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
    analyticsService: _NoopAnalyticsService(),
  );
}

DiscoverFeedController _discoverController({
  List<SavedSearchEntity>? savedSearches,
  List<SmartSearchHistoryEntity>? smartSearchHistory,
}) {
  return DiscoverFeedController(
    getDiscoverFeedUseCase: GetDiscoverFeedUseCase(_FakeDiscoverRepository()),
    discoverPreferencesRepository: _FakeDiscoverPreferencesRepository(
      initialSavedSearches: savedSearches,
      initialSmartSearchHistory: smartSearchHistory,
    ),
    analyticsService: _NoopAnalyticsService(),
  );
}

FavoriteItemEntity _favorite(
  String id,
  String title, {
  bool isFree = true,
  double priceAmount = 0,
  String category = 'wellness',
  String? targetRoute,
}) {
  return FavoriteItemEntity(
    id: id,
    title: title,
    subtitle: 'Subtitle',
    city: 'Rezekne',
    category: category,
    startsAtUtc: DateTime.parse('2026-04-20T10:00:00Z'),
    distanceKm: 1.8,
    priceAmount: priceAmount,
    isFree: isFree,
    savedAtUtc: DateTime.parse('2026-04-20T08:00:00Z'),
    targetRoute: targetRoute,
  );
}

SavedSearchEntity _savedSearch() {
  return SavedSearchEntity(
    id: 'search_museum',
    title: 'Museum ideas',
    subtitle: 'Art · up to 10 · 5 km',
    query: DiscoverQuery.defaults().copyWith(
      queryText: 'museum',
      selectedCategoryIds: const <String>['art'],
      budgetMax: 10,
      radiusMeters: 5000,
      unlimitedRadius: false,
    ),
    createdAtUtc: DateTime.parse('2026-04-21T08:00:00Z'),
  );
}

SmartSearchHistoryEntity _smartSearch() {
  return SmartSearchHistoryEntity(
    id: 'smart_museum',
    prompt: 'museum today under 10',
    query: DiscoverQuery.defaults().copyWith(
      queryText: 'museum',
      selectedCategoryIds: const <String>['art'],
      budgetMax: 10,
      radiusMeters: 5000,
      unlimitedRadius: false,
    ),
    createdAtUtc: DateTime.parse('2026-04-22T08:00:00Z'),
  );
}

SmartSearchHistoryEntity _smartRouteSearch() {
  return SmartSearchHistoryEntity(
    id: 'smart_route',
    prompt:
        'build a free calm walking route for 2 hours with coffee and park near 5 km',
    query: DiscoverQuery.defaults().copyWith(
      queryText: 'route',
      freeOnly: true,
      selectedCategoryIds: const <String>['wellness'],
      radiusMeters: 5000,
      unlimitedRadius: false,
    ),
    createdAtUtc: DateTime.parse('2026-04-23T08:00:00Z'),
  );
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeDiscoverRepository implements DiscoverRepository {
  @override
  Future<DiscoverItemEntity> getDetails(String itemId) async {
    return DiscoverItemEntity(
      id: itemId,
      title: 'Details',
      subtitle: 'Subtitle',
      city: 'Rezekne',
      category: 'wellness',
      startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
      latitude: 56.5099,
      longitude: 27.3332,
      priceAmount: 0,
      distanceKm: 1.2,
      isFree: true,
      relevanceScore: 0.7,
    );
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    return const <DiscoverItemEntity>[];
  }
}

class _FakeDiscoverPreferencesRepository
    implements DiscoverPreferencesRepository {
  _FakeDiscoverPreferencesRepository({
    List<SavedSearchEntity>? initialSavedSearches,
    List<SmartSearchHistoryEntity>? initialSmartSearchHistory,
  }) : _savedSearches = List<SavedSearchEntity>.from(
         initialSavedSearches ?? const <SavedSearchEntity>[],
       ),
       _smartSearchHistory = List<SmartSearchHistoryEntity>.from(
         initialSmartSearchHistory ?? const <SmartSearchHistoryEntity>[],
       );

  DiscoverQuery? _lastQuery;
  final List<SavedSearchEntity> _savedSearches;
  final List<SmartSearchHistoryEntity> _smartSearchHistory;

  @override
  Future<DiscoverQuery?> loadLastQuery() async => _lastQuery;

  @override
  Future<void> saveLastQuery(DiscoverQuery query) async {
    _lastQuery = query;
  }

  @override
  Future<List<SavedSearchEntity>> loadSavedSearches() async {
    return List<SavedSearchEntity>.from(_savedSearches);
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
    return List<SmartSearchHistoryEntity>.from(_smartSearchHistory);
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

class _FakeFavoritesRepository implements FavoritesRepository {
  _FakeFavoritesRepository({List<FavoriteItemEntity>? initial})
    : _storage = initial == null
          ? <FavoriteItemEntity>[]
          : List<FavoriteItemEntity>.from(initial);

  final List<FavoriteItemEntity> _storage;

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {
    _storage.removeWhere((FavoriteItemEntity element) => element.id == item.id);
    _storage.insert(0, item);
  }

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async {
    return List<FavoriteItemEntity>.from(_storage);
  }

  @override
  Future<void> removeFavorite(String itemId) async {
    _storage.removeWhere((FavoriteItemEntity element) => element.id == itemId);
  }
}
