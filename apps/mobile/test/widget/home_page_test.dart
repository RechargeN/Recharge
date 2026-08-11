import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/money_test_values.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:recharge/features/auth/presentation/pages/discover_hub_page.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/discover_providers.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/discover/presentation/pages/categories_page.dart';
import 'package:recharge/features/discover/presentation/pages/category_page.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';

import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets('renders consumer home showcase', (tester) async {
    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();

    expect(find.text('RECHARGE'), findsOneWidget);
    expect(find.text('VACATION APP'), findsOneWidget);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home-search-action'))).height,
      48,
    );
    expect(tester.getSize(find.byKey(const Key('home-map-action'))).height, 48);
    expect(find.text('Categories'), findsWidgets);
    expect(find.text('All'), findsWidgets);
    expect(find.text('Sport'), findsOneWidget);
    expect(find.text('Walks'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('For you'), findsWidgets);
    expect(find.text('Nearly'), findsNothing);
    expect(find.text('Утренняя йога в парке'), findsWidgets);

    final List<Finder> scenarioFeeds = <Finder>[
      find.byKey(const Key('home-feed-Categories')),
      find.byKey(const Key('home-feed-New')),
      find.byKey(const Key('home-feed-For you')),
      find.byKey(const Key('home-feed-Quick events')),
      find.byKey(const Key('home-feed-Nearby')),
      find.byKey(const Key('home-feed-Popular')),
    ];
    for (final Finder feed in scenarioFeeds) {
      expect(feed, findsOneWidget);
    }
    for (int index = 1; index < scenarioFeeds.length; index += 1) {
      expect(
        tester.getTopLeft(scenarioFeeds[index]).dy,
        greaterThan(tester.getTopLeft(scenarioFeeds[index - 1]).dy),
      );
    }
    expect(
      tester
          .getSize(find.byKey(const Key('home-card-Categories-evt_1')))
          .height,
      116,
    );

    await tester.scrollPageUntilVisible(
      find.text('Quick events'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quick events'), findsOneWidget);

    await tester.scrollPageUntilVisible(
      find.text('Nearby'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nearby'), findsOneWidget);

    await tester.scrollPageUntilVisible(
      find.text('Popular').last,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Popular'), findsWidgets);
  });

  fullPageTestWidgets('opens search from hero action', (tester) async {
    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search page'), findsOneWidget);
  });

  fullPageTestWidgets('opens the category catalog from View all', (
    tester,
  ) async {
    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('View all').first);
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.byKey(const Key('categories-search-field')), findsOneWidget);
    expect(find.text('Sport'), findsOneWidget);
    expect(find.text('Music & nightlife'), findsOneWidget);
  });

  testWidgets('category row fits a long title at 360dp', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-category-all')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('categories-search-field')),
      'workshops',
    );
    await tester.pumpAndSettle();

    final Finder row = find.byKey(
      const Key('category-row-workshops_masterclasses'),
    );
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, 64);
    expect(
      tester.getSize(
        find.byKey(const Key('category-icon-workshops_masterclasses')),
      ),
      const Size(42, 42),
    );
    final Text title = tester.widget<Text>(
      find.text('Workshops & masterclasses'),
    );
    expect(title.maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  fullPageTestWidgets('opens category and filters its subcategories', (
    tester,
  ) async {
    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-category-all')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('categories-search-field')),
      'sport',
    );
    await tester.pumpAndSettle();

    expect(find.text('Sport'), findsOneWidget);
    expect(find.text('Music & nightlife'), findsNothing);

    await tester.tap(find.byKey(const Key('category-row-sport')));
    await tester.pumpAndSettle();

    expect(find.text('Subcategories'), findsOneWidget);
    expect(find.byKey(const Key('subcategory-all')), findsOneWidget);
    expect(find.byKey(const Key('subcategory-football')), findsOneWidget);
    expect(find.text('Community football'), findsOneWidget);

    await tester.tap(find.byKey(const Key('subcategory-basketball')));
    await tester.pumpAndSettle();
    expect(find.text('Community football'), findsNothing);
    expect(find.text('0 found'), findsOneWidget);

    await tester.tap(find.byKey(const Key('subcategory-all')));
    await tester.pumpAndSettle();
    expect(find.text('Community football'), findsOneWidget);
  });

  fullPageTestWidgets('home category opens its canonical category page', (
    tester,
  ) async {
    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-category-family_kids')),
      280,
      scrollable: find.byType(Scrollable).at(1),
    );
    await tester.tap(find.byKey(const Key('home-category-family_kids')));
    await tester.pumpAndSettle();

    expect(find.text('Family & kids'), findsWidgets);
    expect(find.text('Subcategories'), findsOneWidget);
    expect(find.byKey(const Key('subcategory-all')), findsOneWidget);
  });

  fullPageTestWidgets('opens saved scenario from home continue panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _HomeTestApp(favoriteItems: <FavoriteItemEntity>[_scenarioFavorite()]),
    );
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Continue your route'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Continue your route'), findsOneWidget);
    expect(find.text('Calm recharge route'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-saved-scenario-edit')));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('food_drinks.coffee'), findsOneWidget);
  });

  fullPageTestWidgets('opens saved scenario route on map from home', (
    tester,
  ) async {
    await tester.pumpWidget(
      _HomeTestApp(favoriteItems: <FavoriteItemEntity>[_scenarioFavorite()]),
    );
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Continue your route'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('home-saved-scenario-route')));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('food_drinks.coffee'), findsOneWidget);
  });

  fullPageTestWidgets('opens route template builder from home', (tester) async {
    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Build').first,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Build').first);
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('coffee reset walk'), findsOneWidget);
  });

  fullPageTestWidgets('opens route template on map from home', (tester) async {
    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.byTooltip('Map Coffee reset route'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Map Coffee reset route'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);
  });

  fullPageTestWidgets('opens create from route template on home', (
    tester,
  ) async {
    await tester.pumpWidget(_HomeTestApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.byTooltip('Create Coffee reset route'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Create Coffee reset route'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('scenario'), findsWidgets);
    expect(find.text('Coffee reset route'), findsOneWidget);
    expect(find.text('coffee reset walk'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
  });

  fullPageTestWidgets('opens saved search from home continuation panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _HomeTestApp(savedSearches: <SavedSearchEntity>[_savedSearch()]),
    );
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Continue saved search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Continue saved search'), findsOneWidget);
    expect(find.text('Museum ideas'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Search page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
  });

  fullPageTestWidgets('opens saved search on map from home', (tester) async {
    await tester.pumpWidget(
      _HomeTestApp(savedSearches: <SavedSearchEntity>[_savedSearch()]),
    );
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Continue saved search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('home-saved-search-map')));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  fullPageTestWidgets('opens route builder from saved search on home', (
    tester,
  ) async {
    await tester.pumpWidget(
      _HomeTestApp(savedSearches: <SavedSearchEntity>[_savedSearch()]),
    );
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Continue saved search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Build route from saved search'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('social'), findsOneWidget);
    expect(find.textContaining('museum'), findsOneWidget);
  });

  fullPageTestWidgets('opens create from saved search on home', (tester) async {
    await tester.pumpWidget(
      _HomeTestApp(savedSearches: <SavedSearchEntity>[_savedSearch()]),
    );
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Continue saved search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Create listing from saved search'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('saved_search'), findsOneWidget);
    expect(find.text('Museum ideas'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
  });

  fullPageTestWidgets('opens smart search continuation actions from home', (
    tester,
  ) async {
    Widget app() {
      return _HomeTestApp(
        smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Continue smart search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Continue smart search'), findsOneWidget);
    expect(find.text('museum today under 10'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Smart Search page'), findsOneWidget);
    expect(find.text('museum today under 10'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Continue smart search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('home-smart-search-map')));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Continue smart search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Build route from smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('social'), findsOneWidget);
    expect(find.text('museum today under 10'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Continue smart search'),
      260,
      scrollable: find.byType(Scrollable).first,
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

  fullPageTestWidgets('keeps smart route intent from home smart continuation', (
    tester,
  ) async {
    Widget app() {
      return _HomeTestApp(
        smartSearchHistory: <SmartSearchHistoryEntity>[_smartRouteSearch()],
      );
    }

    const String prompt =
        'build a free calm walking route for 2 hours with coffee and park near 5 km';

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Continue smart search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Continue smart search'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);
    expect(find.text('Smart route'), findsOneWidget);
    expect(find.text('120 min'), findsWidgets);
    expect(find.text('2 stops'), findsOneWidget);

    await tester.tap(find.byTooltip('Build route from smart search'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Continue smart search'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('home-smart-search-map')));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Continue smart search'),
      260,
      scrollable: find.byType(Scrollable).first,
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
}

class _HomeTestApp extends StatelessWidget {
  _HomeTestApp({
    List<FavoriteItemEntity>? favoriteItems,
    List<SavedSearchEntity>? savedSearches,
    List<SmartSearchHistoryEntity>? smartSearchHistory,
  }) : _favoritesRepository = _FakeFavoritesRepository(initial: favoriteItems),
       _discoverPreferencesRepository = _FakeDiscoverPreferencesRepository(
         initialSavedSearches: savedSearches,
         initialSmartSearchHistory: smartSearchHistory,
       );

  final AuthController _authController = AuthController(
    signInUseCase: SignInUseCase(_NoopAuthRepository()),
    restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
    signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
    getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
    analyticsService: _NoopAnalyticsService(),
  );

  final _FakeFavoritesRepository _favoritesRepository;
  final _FakeDiscoverPreferencesRepository _discoverPreferencesRepository;

  late final DiscoverFeedController _discoverController =
      DiscoverFeedController(
        getDiscoverFeedUseCase: GetDiscoverFeedUseCase(
          _FakeDiscoverRepository(),
        ),
        discoverPreferencesRepository: _discoverPreferencesRepository,
        analyticsService: _NoopAnalyticsService(),
      );

  late final FavoritesController _favoritesController = FavoritesController(
    getFavoritesUseCase: GetFavoritesUseCase(_favoritesRepository),
    addFavoriteUseCase: AddFavoriteUseCase(_favoritesRepository),
    removeFavoriteUseCase: RemoveFavoriteUseCase(_favoritesRepository),
    analyticsService: _NoopAnalyticsService(),
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        authControllerProvider.overrideWith((ref) => _authController),
        discoverFeedControllerProvider.overrideWith(
          (ref) => _discoverController,
        ),
        favoritesControllerProvider.overrideWith((ref) => _favoritesController),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: RouteNames.discover,
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.discover,
              builder: (context, state) =>
                  const DiscoverHubPage(favoriteApplied: false),
            ),
            GoRoute(
              path: RouteNames.categories,
              builder: (context, state) => const CategoriesPage(),
            ),
            GoRoute(
              path: '${RouteNames.categories}/:categoryId',
              builder: (context, state) => CategoryPage(
                categoryId: state.pathParameters['categoryId'] ?? '',
              ),
            ),
            GoRoute(
              path: '${RouteNames.discoverDetails}/:itemId',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Details page'))),
            ),
            GoRoute(
              path: RouteNames.search,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Column(
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
                body: Center(
                  child: Column(
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
            ),
            GoRoute(
              path: RouteNames.scenarioBuilder,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Column(
                    children: <Widget>[
                      const Text('Builder page'),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(state.uri.queryParameters['prompt'] ?? ''),
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
              path: RouteNames.signIn,
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Sign in page'))),
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

class _NoopAuthRepository implements AuthRepository {
  @override
  Future<AuthUserEntity?> getCurrentUser() async => null;

  @override
  Future<AuthResultEntity?> restoreSession() async => null;

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    return AuthResultEntity(
      session: AuthSessionEntity(
        accessToken: 'acc',
        refreshToken: 'ref',
        sessionId: 'sess',
        expiresAtUtc: DateTime.now().toUtc(),
      ),
      user: const AuthUserEntity(
        id: 'u',
        email: 'user@example.com',
        role: 'user',
        capabilities: <String>['discover.read'],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
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
      price: testZeroEur,
      distanceKm: 1.2,
      isFree: true,
      relevanceScore: 0.7,
    );
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    final List<DiscoverItemEntity> items = <DiscoverItemEntity>[
      DiscoverItemEntity(
        id: 'evt_1',
        title: 'Утренняя йога в парке',
        subtitle: 'Легкая практика',
        city: 'Rezekne',
        category: 'wellness_recharge',
        subcategory: 'yoga',
        startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
        latitude: query.centerLat,
        longitude: query.centerLng,
        price: testZeroEur,
        distanceKm: 1.2,
        isFree: true,
        relevanceScore: 0.8,
      ),
      DiscoverItemEntity(
        id: 'evt_sport_1',
        title: 'Community football',
        subtitle: 'Friendly outdoor match',
        city: 'Rezekne',
        category: 'sport',
        subcategory: 'football',
        startsAtUtc: DateTime.parse('2026-04-18T10:00:00Z'),
        latitude: query.centerLat,
        longitude: query.centerLng,
        price: testZeroEur,
        distanceKm: 2.1,
        isFree: true,
        relevanceScore: 0.75,
      ),
    ];
    return items
        .where((DiscoverItemEntity item) {
          if (query.selectedCategoryIds.isNotEmpty &&
              !query.selectedCategoryIds.contains(item.category)) {
            return false;
          }
          if (query.selectedSubcategoryIds.isNotEmpty &&
              !query.selectedSubcategoryIds.contains(item.subcategory)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
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

FavoriteItemEntity _scenarioFavorite() {
  return FavoriteItemEntity(
    id: 'scenario_calm',
    title: 'Calm recharge route',
    subtitle: 'Coffee, walk and recovery stop',
    city: 'Rezekne',
    category: 'scenario',
    startsAtUtc: DateTime.parse('2026-04-20T12:00:00Z'),
    distanceKm: 2.4,
    price: testZeroEur,
    isFree: true,
    savedAtUtc: DateTime.parse('2026-04-20T08:00:00Z'),
    targetRoute:
        '${RouteNames.scenarioBuilder}?mood=calm&steps=food_drinks.coffee',
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
      budgetMax: testTenEur,
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
      budgetMax: testTenEur,
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

class _FakeFavoritesRepository implements FavoritesRepository {
  _FakeFavoritesRepository({List<FavoriteItemEntity>? initial})
    : _items = List<FavoriteItemEntity>.from(
        initial ?? const <FavoriteItemEntity>[],
      );

  final List<FavoriteItemEntity> _items;

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {
    _items.removeWhere((FavoriteItemEntity current) => current.id == item.id);
    _items.add(item);
  }

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async {
    return List<FavoriteItemEntity>.from(_items);
  }

  @override
  Future<void> removeFavorite(String itemId) async {
    _items.removeWhere((FavoriteItemEntity item) => item.id == itemId);
  }
}
