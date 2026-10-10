import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/identity/account_experience.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/features/create/domain/repositories/create_draft_collection_repository.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/explore/presentation/widgets/scenario_library_panel.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/shared/primitives/money/money.dart';
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
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/application/state/create_state.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/discover_runtime_defaults.dart';
import 'package:recharge/features/discover/application/discover_providers.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/explore/application/controllers/explore_controller.dart';
import 'package:recharge/features/explore/application/explore_providers.dart';
import 'package:recharge/features/explore/domain/entities/profile_editable_entity.dart';
import 'package:recharge/features/explore/domain/entities/settings_entity.dart';
import 'package:recharge/features/explore/domain/repositories/explore_repository.dart';
import 'package:recharge/features/explore/domain/usecases/load_profile_editable_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/load_settings_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/save_profile_editable_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/save_settings_usecase.dart';
import 'package:recharge/features/explore/presentation/pages/profile_page.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'package:recharge/features/visited/application/controllers/visited_places_controller.dart';
import 'package:recharge/features/visited/application/visited_places_providers.dart';
import 'package:recharge/features/visited/domain/entities/visited_place_entity.dart';
import 'package:recharge/features/visited/domain/repositories/visited_places_repository.dart';
import 'package:recharge/features/visited/domain/usecases/get_visited_places_usecase.dart';

import 'widget_test_viewport.dart';
import '../support/event_create_test_support.dart';

void main() {
  for (final experience in <AccountExperience?>[
    null,
    AccountExperience.personal,
    AccountExperience.professionalPage,
  ]) {
    fullPageTestWidgets(
      'User personal content and handoffs with scope $experience',
      (tester) async {
        final library = _OwnedScenarioCollection();
        sl.registerSingleton<CreateDraftCollectionRepository>(library);
        addTearDown(() => sl.unregister<CreateDraftCollectionRepository>());
        final controller = _createController(
          initialDraft: _pagePublisherDraft(),
        );
        final app = await _unifiedUserApp(
          experience: experience,
          createController: controller,
        );
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Creator'), findsOneWidget);
        expect(find.text('CREATOR'), findsOneWidget);
        expect(find.text('Created'), findsOneWidget);
        expect(find.text('Visited'), findsOneWidget);
        expect(find.text('Saved list'), findsOneWidget);
        expect(find.text('Create Hub'), findsNothing);
        expect(find.text('Upgrade account'), findsNothing);
        expect(find.text('PROFILE MODE'), findsNothing);
        expect(find.byType(ScenarioLibraryPanel), findsOneWidget);
        expect(find.text('My private Scenario'), findsOneWidget);
        expect(library.requestedOwners, everyElement('creator_1'));
        expect(
          controller.state.draft.eventData?.publisherRef?.id,
          'original-publisher',
        );
        await tester.tap(find.text('My private Scenario'));
        await tester.pumpAndSettle();
        expect(find.text('Scenario exact-owned-scenario'), findsOneWidget);
        // Return through the actual router to the same personal entry.
        GoRouter.of(
          tester.element(find.text('Scenario exact-owned-scenario')),
        ).go(RouteNames.profile);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saved list'));
        await tester.pumpAndSettle();
        expect(find.text('Saved destination'), findsOneWidget);
        GoRouter.of(
          tester.element(find.text('Saved destination')),
        ).go(RouteNames.profile);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Visited'));
        await tester.pumpAndSettle();
        expect(find.text('Visited destination'), findsOneWidget);
        GoRouter.of(
          tester.element(find.text('Visited destination')),
        ).go(RouteNames.profile);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Creator tools'));
        await tester.pumpAndSettle();
        expect(find.text('Settings destination'), findsOneWidget);
        GoRouter.of(
          tester.element(find.text('Settings destination')),
        ).go(RouteNames.profileWorkspace);
        await tester.pumpAndSettle();
        expect(find.text('PROFILE MODE'), findsNothing);
        expect(find.text('User'), findsNothing);
        expect(find.text('Pro'), findsNothing);
        expect(find.text('Build a route'), findsOneWidget);
        await tester.tap(find.text('Build a route'));
        await tester.pumpAndSettle();
        expect(find.text('Create scenario'), findsOneWidget);
        expect(
          controller.state.draft.eventData?.publisherRef?.id,
          'original-publisher',
        );
      },
    );
  }

  testWidgets('personal and direct workspace fit 360 dp at 150 percent text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    final app = await _unifiedUserApp(textScaler: const TextScaler.linear(1.5));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Creator'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Create Scenario'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    GoRouter.of(
      tester.element(find.text('Create Scenario')),
    ).go(RouteNames.profileWorkspace);
    await tester.pumpAndSettle();
    expect(find.text('PROFILE MODE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  fullPageTestWidgets('renders creator role dashboard', (tester) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'creator@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
    final ExploreController exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final _FakeFavoritesRepository favoritesRepository =
        _FakeFavoritesRepository();
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
      addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final DiscoverFeedController discoverController = _discoverController();
    final CreateController createController = _createController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
          createControllerProvider.overrideWith((ref) => createController),
          discoverFeedControllerProvider.overrideWith(
            (ref) => discoverController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.profile,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profile,
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                path: RouteNames.visitedPlaces,
                builder: (context, state) =>
                    const Scaffold(body: Text('Visited places page')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Creator'), findsOneWidget);
    expect(find.text('CREATOR'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Visited'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('PROFILE MODE'), findsNothing);
    expect(find.text('PROFILE MENU'), findsNothing);
    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(find.text('Create Hub'), findsOneWidget);
    expect(find.text('Create route'), findsOneWidget);
    expect(find.text('Create Scenario'), findsOneWidget);
    expect(find.text('One-time event'), findsOneWidget);
    expect(find.text('Find people'), findsOneWidget);

    await tester.tap(find.text('Visited'));
    await tester.pumpAndSettle();
    expect(find.text('Visited places page'), findsOneWidget);
  });

  fullPageTestWidgets(
    'ordinary User shares Creator layout and personal shortcuts without grants',
    (tester) async {
      final AuthController authController = AuthController(
        signInUseCase: SignInUseCase(
          _NoopAuthRepository(
            email: 'viewer@example.com',
            role: 'user',
            capabilities: const <String>['create.event', 'create.place'],
          ),
        ),
        restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
        signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
        getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
        analyticsService: _NoopAnalyticsService(),
      );
      await authController.signIn(
        email: 'viewer@example.com',
        password: 'password123',
        sourceScreen: 'test',
        sourceAction: 'seed',
      );

      final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
      final ExploreController exploreController = ExploreController(
        loadProfileEditableUseCase: LoadProfileEditableUseCase(
          exploreRepository,
        ),
        saveProfileEditableUseCase: SaveProfileEditableUseCase(
          exploreRepository,
        ),
        loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
        saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
        analyticsService: _NoopAnalyticsService(),
      );
      final _FakeFavoritesRepository favoritesRepository =
          _FakeFavoritesRepository();
      final FavoritesController favoritesController = FavoritesController(
        getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
        addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
        removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
        analyticsService: _NoopAnalyticsService(),
      );
      final VisitedPlacesController visitedController = VisitedPlacesController(
        getVisitedPlacesUseCase: GetVisitedPlacesUseCase(
          _FakeVisitedPlacesRepository(
            items: <VisitedPlaceEntity>[
              VisitedPlaceEntity(
                id: '4a3d27ad-8185-4b94-a991-9b36b6f62c16',
                userId: 'creator_1',
                placeId: 'evt_rig_002',
                title: 'Lake walk',
                subtitle: 'Five calm kilometres',
                city: 'Riga',
                category: 'outdoor_nature_walking',
                visitedOn: DateTime(2026, 7, 20),
                timezoneId: 'Europe/Riga',
                evidence: VisitEvidence.selfReported,
                recordedAtUtc: DateTime.utc(2026, 7, 20, 12),
              ),
            ],
          ),
        ),
        analyticsService: _NoopAnalyticsService(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authControllerProvider.overrideWith((ref) => authController),
            exploreControllerProvider.overrideWith((ref) => exploreController),
            favoritesControllerProvider.overrideWith(
              (ref) => favoritesController,
            ),
            createControllerProvider.overrideWith((ref) => _createController()),
            discoverFeedControllerProvider.overrideWith(
              (ref) => _discoverController(),
            ),
            visitedPlacesControllerProvider.overrideWith(
              (ref) => visitedController,
            ),
          ],
          child: const MaterialApp(home: ProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Creator'), findsOneWidget);
      expect(find.text('VIEWER'), findsNothing);
      expect(find.text('Visited'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('VISITED PLACES'), findsNothing);
      expect(find.text('Lake walk'), findsNothing);
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.text('Saved list'), findsOneWidget);
      expect(find.text('Upgrade account'), findsNothing);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('PROFILE MODE'), findsNothing);
    },
  );

  fullPageTestWidgets('generator retains tools inside unified Creator layout', (
    tester,
  ) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(
        _NoopAuthRepository(
          email: 'pro@example.com',
          role: 'pro_generator',
          capabilities: const <String>[
            'create.event',
            'create.place',
            'scenario.generate',
            'pro.generator',
          ],
        ),
      ),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'pro@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
    final ExploreController exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final _FakeFavoritesRepository favoritesRepository =
        _FakeFavoritesRepository();
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
      addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
          createControllerProvider.overrideWith((ref) => _createController()),
          discoverFeedControllerProvider.overrideWith(
            (ref) => _discoverController(),
          ),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Creator'), findsOneWidget);
    expect(find.text('PRO GENERATOR'), findsNothing);
    expect(find.text('Visited'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Insights'), findsNothing);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('MANAGED PAGE'), findsNothing);
    expect(find.text('CONTROL CENTER'), findsOneWidget);
    expect(find.text('Manage page'), findsOneWidget);
    expect(find.text('Created events'), findsOneWidget);
    expect(find.text('Event insights'), findsOneWidget);
    expect(find.text('Bookings & requests'), findsOneWidget);
    expect(find.text('PROFILE MODE'), findsNothing);

    expect(find.text('LATEST CREATED EVENTS'), findsOneWidget);
    expect(find.text('MANAGED PAGE'), findsNothing);
    expect(find.text('Create Hub'), findsOneWidget);
  });

  fullPageTestWidgets('ignores legacy favorite Scenario in profile workspace', (
    tester,
  ) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(
        _NoopAuthRepository(
          email: 'pro@example.com',
          role: 'pro_generator',
          capabilities: const <String>[
            'pro.generator',
            'scenario.generate',
            'create.event',
          ],
        ),
      ),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'pro@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
    final ExploreController exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final _FakeFavoritesRepository favoritesRepository =
        _FakeFavoritesRepository(
          initial: <FavoriteItemEntity>[_scenarioFavorite()],
        );
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
      addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final DiscoverFeedController discoverController = _discoverController(
      savedSearches: <SavedSearchEntity>[_savedSearch()],
    );
    final CreateController createController = _createController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
          createControllerProvider.overrideWith((ref) => createController),
          discoverFeedControllerProvider.overrideWith(
            (ref) => discoverController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.profileWorkspace,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profileWorkspace,
                builder: (context, state) => const ProfileWorkspacePage(),
              ),
              GoRoute(
                path: RouteNames.legacyScenarioBuilder,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Builder page'),
                      Text(state.uri.queryParameters['steps'] ?? ''),
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
                    ],
                  ),
                ),
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
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: RouteNames.favorites,
                builder: (context, state) =>
                    const Scaffold(body: Text('Favorites page')),
              ),
              GoRoute(
                path: RouteNames.settings,
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings page')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pro'), findsNothing);
    expect(find.text('Latest route'), findsNothing);
    expect(find.text('Calm recharge route'), findsNothing);
  });

  fullPageTestWidgets('opens latest saved search from profile workspace', (
    tester,
  ) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'creator@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
    final ExploreController exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final _FakeFavoritesRepository favoritesRepository =
        _FakeFavoritesRepository();
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
      addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final DiscoverFeedController discoverController = _discoverController(
      savedSearches: <SavedSearchEntity>[_savedSearch()],
    );
    final CreateController createController = _createController();

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
          createControllerProvider.overrideWith((ref) => createController),
          discoverFeedControllerProvider.overrideWith(
            (ref) => discoverController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.profileWorkspace,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profileWorkspace,
                builder: (context, state) => const ProfileWorkspacePage(),
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
                path: RouteNames.legacyScenarioBuilder,
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
              GoRoute(
                path: RouteNames.favorites,
                builder: (context, state) =>
                    const Scaffold(body: Text('Favorites page')),
              ),
              GoRoute(
                path: RouteNames.settings,
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings page')),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Latest search'), findsOneWidget);
    expect(find.text('Museum ideas'), findsOneWidget);

    await tester.scrollPageUntilVisible(find.text('Resume search').first, 200);
    await tester.tap(find.text('Resume search').first);
    await tester.pumpAndSettle();

    expect(find.text('Search page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(find.text('Map search').first, 200);
    await tester.tap(find.text('Map search').first);
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.byTooltip('Build route from latest search').first,
      200,
    );
    await tester.tap(find.byTooltip('Build route from latest search').first);
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('saved_search_route_seed'), findsOneWidget);
    expect(find.text('route'), findsWidgets);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.byTooltip('Create listing from latest search').first,
      200,
    );
    await tester.tap(find.byTooltip('Create listing from latest search').first);
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('saved_search'), findsOneWidget);
    expect(find.text('Museum ideas'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
  });

  fullPageTestWidgets('opens latest smart search from profile workspace', (
    tester,
  ) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'creator@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
    final ExploreController exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final _FakeFavoritesRepository favoritesRepository =
        _FakeFavoritesRepository();
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
      addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final DiscoverFeedController discoverController = _discoverController(
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
    );
    final CreateController createController = _createController();

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
          createControllerProvider.overrideWith((ref) => createController),
          discoverFeedControllerProvider.overrideWith(
            (ref) => discoverController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.profileWorkspace,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profileWorkspace,
                builder: (context, state) => const ProfileWorkspacePage(),
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
                      Text(state.uri.queryParameters['q'] ?? ''),
                      Text(state.uri.queryParameters['category'] ?? ''),
                      Text(state.uri.queryParameters['budgetMax'] ?? ''),
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: RouteNames.legacyScenarioBuilder,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Builder page'),
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(state.uri.queryParameters['prompt'] ?? ''),
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
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: RouteNames.favorites,
                builder: (context, state) =>
                    const Scaffold(body: Text('Favorites page')),
              ),
              GoRoute(
                path: RouteNames.settings,
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings page')),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Latest smart search'), findsOneWidget);
    expect(find.text('museum today under 10'), findsOneWidget);

    await tester.scrollPageUntilVisible(find.text('Resume smart').first, 200);
    await tester.tap(find.text('Resume smart').first);
    await tester.pumpAndSettle();

    expect(find.text('Smart Search page'), findsOneWidget);
    expect(find.text('museum today under 10'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(find.text('Map smart').first, 200);
    await tester.tap(find.text('Map smart').first);
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.byTooltip('Build route from latest smart search').first,
      200,
    );
    await tester.tap(
      find.byTooltip('Build route from latest smart search').first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('saved_search_route_seed'), findsOneWidget);
    expect(find.text('route'), findsWidgets);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.byTooltip('Create listing from latest smart search').first,
      200,
    );
    await tester.tap(
      find.byTooltip('Create listing from latest smart search').first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('smart_search'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
  });

  fullPageTestWidgets(
    'keeps smart route intent from profile latest smart search',
    (tester) async {
      final AuthController authController = AuthController(
        signInUseCase: SignInUseCase(_NoopAuthRepository()),
        restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
        signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
        getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
        analyticsService: _NoopAnalyticsService(),
      );
      await authController.signIn(
        email: 'creator@example.com',
        password: 'password123',
        sourceScreen: 'test',
        sourceAction: 'seed',
      );

      final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
      final ExploreController exploreController = ExploreController(
        loadProfileEditableUseCase: LoadProfileEditableUseCase(
          exploreRepository,
        ),
        saveProfileEditableUseCase: SaveProfileEditableUseCase(
          exploreRepository,
        ),
        loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
        saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
        analyticsService: _NoopAnalyticsService(),
      );
      final _FakeFavoritesRepository favoritesRepository =
          _FakeFavoritesRepository();
      final FavoritesController favoritesController = FavoritesController(
        getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
        addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
        removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
        analyticsService: _NoopAnalyticsService(),
      );
      final DiscoverFeedController discoverController = _discoverController(
        smartSearchHistory: <SmartSearchHistoryEntity>[_smartRouteSearch()],
      );
      final CreateController createController = _createController();

      Widget app() {
        return ProviderScope(
          overrides: <Override>[
            authControllerProvider.overrideWith((ref) => authController),
            exploreControllerProvider.overrideWith((ref) => exploreController),
            favoritesControllerProvider.overrideWith(
              (ref) => favoritesController,
            ),
            createControllerProvider.overrideWith((ref) => createController),
            discoverFeedControllerProvider.overrideWith(
              (ref) => discoverController,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: RouteNames.profileWorkspace,
              routes: <RouteBase>[
                GoRoute(
                  path: RouteNames.profileWorkspace,
                  builder: (context, state) => const ProfileWorkspacePage(),
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
                GoRoute(
                  path: RouteNames.legacyScenarioBuilder,
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
                        Text(state.uri.queryParameters['type'] ?? ''),
                        Text(state.uri.queryParameters['steps'] ?? ''),
                      ],
                    ),
                  ),
                ),
                GoRoute(
                  path: RouteNames.search,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Search page')),
                ),
                GoRoute(
                  path: RouteNames.favorites,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Favorites page')),
                ),
                GoRoute(
                  path: RouteNames.settings,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Settings page')),
                ),
              ],
            ),
          ),
        );
      }

      const String prompt =
          'build a free calm walking route for 2 hours with coffee and park near 5 km';

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Latest smart search'), findsOneWidget);
      expect(find.text(prompt), findsOneWidget);
      expect(find.text('Smart route'), findsOneWidget);
      expect(find.text('120 min'), findsOneWidget);
      expect(find.text('2 stops'), findsOneWidget);

      await tester.scrollPageUntilVisible(
        find.byTooltip('Build route from latest smart search').first,
        200,
      );
      await tester.tap(
        find.byTooltip('Build route from latest smart search').first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Create page'), findsOneWidget);
      expect(find.text('smart_route_seed'), findsOneWidget);
      expect(find.text('route'), findsWidgets);
      expect(find.textContaining('food_drinks.coffee'), findsOneWidget);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.scrollPageUntilVisible(find.text('Map smart').first, 200);
      await tester.tap(find.text('Map smart').first);
      await tester.pumpAndSettle();

      expect(find.text('Map page'), findsOneWidget);
      expect(find.text('route'), findsOneWidget);
      expect(
        find.textContaining('wellness_recharge.calm_walk'),
        findsOneWidget,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.scrollPageUntilVisible(
        find.byTooltip('Create listing from latest smart search').first,
        200,
      );
      await tester.tap(
        find.byTooltip('Create listing from latest smart search'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create page'), findsOneWidget);
      expect(find.text('route'), findsWidgets);
      expect(find.text('Calm recharge route'), findsOneWidget);
      expect(find.text(prompt), findsOneWidget);
      expect(find.text('route'), findsWidgets);
      expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
    },
  );

  fullPageTestWidgets('shows creator listing status in profile workspace', (
    tester,
  ) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'creator@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
    final ExploreController exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final _FakeFavoritesRepository favoritesRepository =
        _FakeFavoritesRepository();
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
      addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final DiscoverFeedController discoverController = _discoverController();
    final CreateController createController = _createController();
    await createController.ensureLoaded(
      userId: 'creator_1',
      organizerEmail: 'creator@example.com',
      organizerName: 'creator',
    );
    // Generic creator-listing-status fixture: Class / Workshop with an applicable
    // Workshops & masterclasses category.
    createController.setObjectType(CreateObjectType.classWorkshop);
    createController.updateTitle('Museum evening route');
    createController.applyTaxonomySelection(
      mainCategory: 'workshops_masterclasses',
      subcategory: 'workshop',
    );
    createController.updateCity('Rezekne');
    createController.updateVenueName('City museum');
    createController.updateShortDescription('A guided creator listing.');
    createController.updateCoverImage(
      'https://images.unsplash.com/photo-1518998053901-5348d3961a04',
    );
    createController.updateIsFree(false);
    createController.updateBasePrice('12');
    createController.updateStartDateTime('2026-04-18T18:00:00Z');
    await createController.publishDraft();

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
          createControllerProvider.overrideWith((ref) => createController),
          discoverFeedControllerProvider.overrideWith(
            (ref) => discoverController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.profileWorkspace,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profileWorkspace,
                builder: (context, state) => const ProfileWorkspacePage(),
              ),
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) =>
                    const Scaffold(body: Text('Create page')),
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
                      Text(state.uri.queryParameters['q'] ?? ''),
                      Text(state.uri.queryParameters['category'] ?? ''),
                      Text(state.uri.queryParameters['budgetMax'] ?? ''),
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: RouteNames.favorites,
                builder: (context, state) =>
                    const Scaffold(body: Text('Favorites page')),
              ),
              GoRoute(
                path: RouteNames.settings,
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings page')),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Creator listing'), findsOneWidget);
    expect(find.text('Museum evening route'), findsOneWidget);
    expect(find.text('pendingReview'), findsOneWidget);
    expect(find.text('Workshops & masterclasses'), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('12 EUR'), findsOneWidget);

    await tester.scrollPageUntilVisible(find.text('Open Create').first, 220);
    await tester.tap(find.text('Open Create').first);
    await tester.pumpAndSettle();
    expect(find.text('Create page'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.byTooltip('Search similar listing').first,
      220,
    );
    await tester.tap(find.byTooltip('Search similar listing').first);
    await tester.pumpAndSettle();
    expect(find.text('Search page'), findsOneWidget);
    expect(find.text('Museum evening route'), findsOneWidget);
    expect(find.text('workshops_masterclasses'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.byTooltip('Map listing area').first,
      220,
    );
    await tester.tap(find.byTooltip('Map listing area').first);
    await tester.pumpAndSettle();
    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('Museum evening route'), findsOneWidget);
    expect(find.text('workshops_masterclasses'), findsOneWidget);
  });

  fullPageTestWidgets('opens legacy route-context activity from profile workspace', (
    tester,
  ) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'creator@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
    final ExploreController exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final _FakeFavoritesRepository favoritesRepository =
        _FakeFavoritesRepository();
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
      addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final DiscoverFeedController discoverController = _discoverController();
    // Historical fixture, not a publish: 'travel_tours'/'walking_tour' is not
    // an applicable category for the activity type under today's validators.
    final CreateController createController =
        _HistoricalListingCreateController(
          repository: _FakeCreateRepository(),
          historicalListing: _legacyRouteContextListing(
            title: 'Calm coffee walking route',
            fullDescription:
                'Route steps: food_drinks.coffee,wellness_recharge.calm_walk,'
                'outdoor_nature_walking. Review the route before publishing.',
            startsAtUtc: '2026-04-18T10:00:00Z',
          ),
        );
    await createController.ensureLoaded(
      userId: 'creator_1',
      organizerEmail: 'creator@example.com',
      organizerName: 'creator',
    );

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
          createControllerProvider.overrideWith((ref) => createController),
          discoverFeedControllerProvider.overrideWith(
            (ref) => discoverController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.profileWorkspace,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profileWorkspace,
                builder: (context, state) => const ProfileWorkspacePage(),
              ),
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) =>
                    const Scaffold(body: Text('Create page')),
              ),
              GoRoute(
                path: RouteNames.legacyScenarioBuilder,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Builder page'),
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(
                        'duration:${state.uri.queryParameters['duration'] ?? ''}',
                      ),
                      Text('free:${state.uri.queryParameters['free'] ?? ''}'),
                      Text(
                        'walking:${state.uri.queryParameters['walking'] ?? ''}',
                      ),
                      Text(state.uri.queryParameters['prompt'] ?? ''),
                      Text(state.uri.queryParameters['steps'] ?? ''),
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
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(
                        'duration:${state.uri.queryParameters['duration'] ?? ''}',
                      ),
                      Text(state.uri.queryParameters['prompt'] ?? ''),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: RouteNames.favorites,
                builder: (context, state) =>
                    const Scaffold(body: Text('Favorites page')),
              ),
              GoRoute(
                path: RouteNames.settings,
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings page')),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Creator listing'), findsOneWidget);
    expect(find.text('Published route'), findsOneWidget);
    expect(find.text('Calm coffee walking route'), findsWidgets);
    expect(find.text('Walking tour'), findsOneWidget);
    expect(find.text('3 stops'), findsOneWidget);
    expect(find.text('90 min'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);

    await tester.scrollPageUntilVisible(find.text('Edit route').last, 220);
    await tester.tap(find.text('Edit route').last);
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(find.text('Route map').first, 220);
    await tester.tap(find.text('Route map').first);
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('route'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('duration:90'), findsOneWidget);
    expect(find.text('Calm coffee walking route'), findsOneWidget);
    expect(
      find.text(
        'food_drinks.coffee,wellness_recharge.calm_walk,'
        'outdoor_nature_walking',
      ),
      findsOneWidget,
    );
  });

  fullPageTestWidgets(
    'manages draft and published listings from creator publications',
    (tester) async {
      final AuthController authController = AuthController(
        signInUseCase: SignInUseCase(_NoopAuthRepository()),
        restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
        signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
        getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
        analyticsService: _NoopAnalyticsService(),
      );
      await authController.signIn(
        email: 'creator@example.com',
        password: 'password123',
        sourceScreen: 'test',
        sourceAction: 'seed',
      );

      final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
      final ExploreController exploreController = ExploreController(
        loadProfileEditableUseCase: LoadProfileEditableUseCase(
          exploreRepository,
        ),
        saveProfileEditableUseCase: SaveProfileEditableUseCase(
          exploreRepository,
        ),
        loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
        saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
        analyticsService: _NoopAnalyticsService(),
      );
      final _FakeFavoritesRepository favoritesRepository =
          _FakeFavoritesRepository();
      final FavoritesController favoritesController = FavoritesController(
        getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
        addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
        removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
        analyticsService: _NoopAnalyticsService(),
      );
      final DiscoverFeedController discoverController = _discoverController();
      // The published listing is the explicit historical legacy
      // route-context fixture; only the current draft is created live, with
      // a valid Class / Workshop category.
      final CreateController
      createController = _HistoricalListingCreateController(
        repository: _FakeCreateRepository(),
        historicalListing: _legacyRouteContextListing(
          title: 'Published calm route',
          fullDescription:
              'Route steps: food_drinks.coffee,wellness_recharge.calm_walk. '
              'Review the route before publishing.',
          startsAtUtc: '2026-04-18T10:00:00Z',
        ),
      );
      await createController.ensureLoaded(
        userId: 'creator_1',
        organizerEmail: 'creator@example.com',
        organizerName: 'creator',
      );
      createController.setObjectType(CreateObjectType.classWorkshop);
      createController.updateTitle('Draft pottery workshop');
      createController.applyTaxonomySelection(
        mainCategory: 'workshops_masterclasses',
        subcategory: 'pottery',
      );
      createController.updateShortDescription('Hands-on clay evening.');
      createController.updateFullDescription('Small creator workshop draft.');
      createController.updateVenueName('City studio');
      createController.updateCity('Rezekne');
      createController.updateCoverImage(
        'https://images.unsplash.com/photo-1518998053901-5348d3961a04',
      );
      createController.updateStartDateTime('2026-04-18T18:00:00Z');
      createController.updateIsFree(false);
      createController.updateBasePrice('8');

      Widget app() {
        return ProviderScope(
          overrides: <Override>[
            authControllerProvider.overrideWith((ref) => authController),
            exploreControllerProvider.overrideWith((ref) => exploreController),
            favoritesControllerProvider.overrideWith(
              (ref) => favoritesController,
            ),
            createControllerProvider.overrideWith((ref) => createController),
            discoverFeedControllerProvider.overrideWith(
              (ref) => discoverController,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: RouteNames.profileWorkspace,
              routes: <RouteBase>[
                GoRoute(
                  path: RouteNames.profileWorkspace,
                  builder: (context, state) => const ProfileWorkspacePage(),
                ),
                GoRoute(
                  path: RouteNames.create,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Create page')),
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
                        Text(state.uri.queryParameters['q'] ?? ''),
                        Text(state.uri.queryParameters['category'] ?? ''),
                        Text(state.uri.queryParameters['steps'] ?? ''),
                      ],
                    ),
                  ),
                ),
                GoRoute(
                  path: RouteNames.legacyScenarioBuilder,
                  builder: (context, state) => Scaffold(
                    body: Column(
                      children: <Widget>[
                        const Text('Builder page'),
                        Text(state.uri.queryParameters['prompt'] ?? ''),
                        Text(state.uri.queryParameters['steps'] ?? ''),
                      ],
                    ),
                  ),
                ),
                GoRoute(
                  path: RouteNames.favorites,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Favorites page')),
                ),
                GoRoute(
                  path: RouteNames.settings,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Settings page')),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Creator publications'), findsOneWidget);
      expect(find.text('2 active'), findsOneWidget);
      expect(find.text('Creator listing'), findsNWidgets(2));
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Draft pottery workshop'), findsOneWidget);
      expect(find.text('Published calm route'), findsWidgets);
      expect(find.text('Ready to publish'), findsOneWidget);
      expect(find.text('Published-ready'), findsOneWidget);
      expect(find.text('Creator next steps'), findsOneWidget);
      expect(find.text('2 actions'), findsOneWidget);
      expect(find.text('Find draft audience'), findsOneWidget);
      expect(find.text('Open route map'), findsOneWidget);

      await tester.scrollPageUntilVisible(
        find.text('Continue draft').first,
        220,
      );
      await tester.tap(find.text('Continue draft').first);
      await tester.pumpAndSettle();
      expect(find.text('Create page'), findsOneWidget);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.scrollPageUntilVisible(
        find.text('Find draft audience').first,
        220,
      );
      await tester.tap(find.text('Find draft audience').first);
      await tester.pumpAndSettle();
      expect(find.text('Search page'), findsOneWidget);
      expect(find.text('Draft pottery workshop'), findsOneWidget);
      expect(find.text('workshops_masterclasses'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.scrollPageUntilVisible(
        find.text('Open route map').first,
        220,
      );
      await tester.tap(find.text('Open route map').first);
      await tester.pumpAndSettle();
      expect(find.text('Map page'), findsOneWidget);
      expect(find.text('route'), findsOneWidget);
      expect(
        find.text('food_drinks.coffee,wellness_recharge.calm_walk'),
        findsOneWidget,
      );
    },
  );

  fullPageTestWidgets('suggests finishing incomplete creator draft', (
    tester,
  ) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'creator@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeExploreRepository exploreRepository = _FakeExploreRepository();
    final ExploreController exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final _FakeFavoritesRepository favoritesRepository =
        _FakeFavoritesRepository();
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
      addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    final DiscoverFeedController discoverController = _discoverController();
    final CreateController createController = _createController();
    await createController.ensureLoaded(
      userId: 'creator_1',
      organizerEmail: 'creator@example.com',
      organizerName: 'creator',
    );
    createController.setObjectType(CreateObjectType.activity);
    createController.updateTitle('Incomplete breathwork draft');
    createController.applyTaxonomySelection(
      mainCategory: 'wellness_recharge',
      subcategory: 'breathwork',
    );
    createController.updateShortDescription('Needs place and cover.');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
          createControllerProvider.overrideWith((ref) => createController),
          discoverFeedControllerProvider.overrideWith(
            (ref) => discoverController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.profileWorkspace,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.profileWorkspace,
                builder: (context, state) => const ProfileWorkspacePage(),
              ),
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) =>
                    const Scaffold(body: Text('Create page')),
              ),
              GoRoute(
                path: RouteNames.favorites,
                builder: (context, state) =>
                    const Scaffold(body: Text('Favorites page')),
              ),
              GoRoute(
                path: RouteNames.settings,
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings page')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Creator publications'), findsOneWidget);
    expect(find.text('Incomplete breathwork draft'), findsOneWidget);
    // Recharge Activity no longer requires startDateTimeUtc (ACT-CRT-01
    // spec AC #2: self-directed, evergreen, no start time) — only the
    // cover image is missing from this draft now.
    expect(find.text('1 missing'), findsOneWidget);
    expect(find.text('Creator next steps'), findsOneWidget);
    expect(find.text('Finish draft'), findsOneWidget);
    expect(find.text('Missing: cover'), findsWidgets);

    await tester.scrollPageUntilVisible(find.text('Finish draft').first, 220);
    await tester.tap(find.text('Finish draft').first);
    await tester.pumpAndSettle();
    expect(find.text('Create page'), findsOneWidget);
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

CreateDraftEntity _pagePublisherDraft() {
  final base = CreateDraftEntity.defaults(
    organizerId: 'creator_1',
    organizerEmail: 'personal@example.com',
    organizerName: 'Personal',
  );
  return base.copyWith(
    eventData: base.eventData!.copyWith(
      publisherRef: const PublisherRef(
        type: PublisherType.page,
        id: 'original-publisher',
      ),
    ),
  );
}

Future<Widget> _unifiedUserApp({
  AccountExperience? experience,
  CreateController? createController,
  TextScaler? textScaler,
}) async {
  final repository = _NoopAuthRepository(role: 'user', capabilities: const []);
  final auth = AuthController(
    signInUseCase: SignInUseCase(repository),
    restoreSessionUseCase: RestoreSessionUseCase(repository),
    signOutUseCase: SignOutUseCase(repository),
    getCurrentUserUseCase: GetCurrentUserUseCase(repository),
    analyticsService: _NoopAnalyticsService(),
  );
  await auth.signIn(
    email: 'personal@example.com',
    password: 'password123',
    sourceScreen: 'test',
    sourceAction: 'seed',
  );
  final exploreRepository = _FakeExploreRepository();
  final explore = ExploreController(
    loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
    saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
    loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
    saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
    analyticsService: _NoopAnalyticsService(),
  );
  final favoritesRepository = _FakeFavoritesRepository();
  final favorites = FavoritesController(
    getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
    addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
    removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
    analyticsService: _NoopAnalyticsService(),
  );
  Widget scope(Widget child) => experience == null
      ? child
      : AccountExperienceScope(experience: experience, child: child);
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      exploreControllerProvider.overrideWith((ref) => explore),
      favoritesControllerProvider.overrideWith((ref) => favorites),
      createControllerProvider.overrideWith(
        (ref) => createController ?? _createController(),
      ),
      discoverFeedControllerProvider.overrideWith(
        (ref) => _discoverController(),
      ),
    ],
    child: MaterialApp.router(
      builder: (context, child) => textScaler == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      routerConfig: GoRouter(
        initialLocation: RouteNames.profile,
        routes: [
          GoRoute(
            path: RouteNames.profile,
            builder: (context, state) => scope(const ProfilePage()),
          ),
          GoRoute(
            path: RouteNames.profileWorkspace,
            builder: (context, state) => scope(const ProfileWorkspacePage()),
          ),
          GoRoute(
            path: RouteNames.favorites,
            builder: (context, state) =>
                const Scaffold(body: Text('Saved destination')),
          ),
          GoRoute(
            path: RouteNames.visitedPlaces,
            builder: (context, state) =>
                const Scaffold(body: Text('Visited destination')),
          ),
          GoRoute(
            path: RouteNames.settings,
            builder: (context, state) =>
                const Scaffold(body: Text('Settings destination')),
          ),
          GoRoute(
            path: RouteNames.create,
            builder: (context, state) => Scaffold(
              body: Text('Create ${state.uri.queryParameters['type']}'),
            ),
          ),
          GoRoute(
            path: RouteNames.createObjectFor('scenario'),
            builder: (context, state) => Scaffold(
              body: Text(
                'Scenario ${state.uri.queryParameters['scenarioDraftId']}',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OwnedScenarioCollection implements CreateDraftCollectionRepository {
  final List<String> requestedOwners = [];
  @override
  Future<List<CreateDraftSummary>> listDrafts({
    required String ownerId,
    required CreateObjectType type,
  }) async {
    requestedOwners.add(ownerId);
    return [
      CreateDraftSummary(
        id: 'exact-owned-scenario',
        objectType: type,
        title: 'My private Scenario',
        updatedAtUtc: DateTime.utc(2026, 10, 10),
      ),
    ];
  }

  @override
  Future<CreateDraftEntity?> loadDraftById({
    required String ownerId,
    required String draftId,
  }) async {
    requestedOwners.add(ownerId);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopAuthRepository implements AuthRepository {
  _NoopAuthRepository({
    this.email = 'creator@example.com',
    this.role = 'creator',
    this.capabilities = const <String>['create.event', 'create.place'],
  });

  final String email;
  final String role;
  final List<String> capabilities;

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
      user: AuthUserEntity(
        id: 'creator_1',
        email: email,
        role: role,
        capabilities: capabilities,
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class _FakeExploreRepository implements ExploreRepository {
  final Map<String, ProfileEditableEntity> _profiles =
      <String, ProfileEditableEntity>{};
  final Map<String, SettingsEntity> _settings = <String, SettingsEntity>{};

  @override
  Future<ProfileEditableEntity?> loadProfileEditable(String userId) async {
    return _profiles[userId];
  }

  @override
  Future<SettingsEntity?> loadSettings(String userId) async {
    return _settings[userId];
  }

  @override
  Future<void> saveProfileEditable(
    String userId,
    ProfileEditableEntity profile,
  ) async {
    _profiles[userId] = profile;
  }

  @override
  Future<void> saveSettings(String userId, SettingsEntity settings) async {
    _settings[userId] = settings;
  }
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
    runtimeDefaults: const DiscoverRuntimeDefaults(
      timezoneId: 'Europe/Riga',
      originLat: 56.9496,
      originLng: 24.1052,
      currencyCode: 'EUR',
    ),
  );
}

CreateController _createController({CreateDraftEntity? initialDraft}) {
  final _FakeCreateRepository repository = _FakeCreateRepository(
    initialDraft: initialDraft,
  );
  return CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
    analyticsService: _NoopAnalyticsService(),
    eventCreateCoordinator: createTestEventCoordinator(),
    runtimeDefaults: const CreateRuntimeDefaults(
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'Latvia',
      city: 'Riga',
      currency: 'EUR',
    ),
  );
}

/// Explicit HISTORICAL fixture for the legacy route-context rendering
/// (`travel_tours`/`walking_tour` activity listing whose steps live in the
/// full description). That category/type pairing is not creatable through
/// today's validators, so it must not be produced by a successful publish in
/// a test; the profile reads it as an already-published listing instead.
CreateDraftEntity _legacyRouteContextListing({
  required String title,
  required String fullDescription,
  required String startsAtUtc,
}) {
  final CreateDraftEntity base = CreateDraftEntity.defaults(
    organizerId: 'creator_1',
    organizerEmail: 'creator@example.com',
    organizerName: 'creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'Latvia',
    city: 'Riga',
    currency: 'EUR',
  );
  return base.copyWith(
    objectType: CreateObjectType.activity,
    title: title,
    mainCategory: 'travel_tours',
    subcategory: 'walking_tour',
    city: 'Rezekne',
    venueName: 'Old town start',
    shortDescription: '90 min calm creator route.',
    fullDescription: fullDescription,
    media: const MediaEntity(
      coverImage:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
      gallery: <String>[],
    ),
    startDateTimeUtc: DateTime.parse(startsAtUtc),
    draftStatus: DraftStatus.pendingReview,
    moderationStatus: ModerationStatus.pending,
    publishStatus: PublishStatus.pendingReview,
    publishedAtUtc: DateTime.utc(2026, 4, 18, 9),
  );
}

/// Create controller whose `publishedDraft` is a preloaded historical
/// listing; the current editable draft still behaves normally.
class _HistoricalListingCreateController extends CreateController {
  _HistoricalListingCreateController({
    required CreateRepository repository,
    required CreateDraftEntity historicalListing,
  }) : _historicalListing = historicalListing,
       super(
         loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
         saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
         publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
         analyticsService: _NoopAnalyticsService(),
         eventCreateCoordinator: createTestEventCoordinator(),
         runtimeDefaults: const CreateRuntimeDefaults(
           marketCityId: 'riga',
           timezone: 'Europe/Riga',
           country: 'Latvia',
           city: 'Riga',
           currency: 'EUR',
         ),
       );

  final CreateDraftEntity _historicalListing;

  @override
  CreateState get state =>
      super.state.copyWith(publishedDraft: _historicalListing);
}

class _FakeCreateRepository implements CreateRepository {
  _FakeCreateRepository({CreateDraftEntity? initialDraft})
    : _stored = initialDraft;

  CreateDraftEntity? _stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => _stored;

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    _stored = draft.copyWith(
      draftStatus: DraftStatus.pendingReview,
      moderationStatus: ModerationStatus.pending,
      publishStatus: PublishStatus.pendingReview,
      publishedAtUtc: now,
      updatedAtUtc: now,
    );
    return _stored!;
  }

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    _stored = draft;
  }
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
      priceAmount: const Money(minorUnits: 0, currencyCode: 'EUR'),
      distanceKm: 1.2,
      isFree: true,
      relevanceScore: 0.7,
    );
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    return <DiscoverItemEntity>[
      DiscoverItemEntity(
        id: 'evt_1',
        title: 'Утренняя йога',
        subtitle: 'Легкая практика',
        city: 'Rezekne',
        category: 'wellness',
        startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
        latitude: query.centerLat,
        longitude: query.centerLng,
        priceAmount: const Money(minorUnits: 0, currencyCode: 'EUR'),
        distanceKm: 1.2,
        isFree: true,
        relevanceScore: 0.8,
      ),
    ];
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
    : _items = List<FavoriteItemEntity>.from(
        initial ?? const <FavoriteItemEntity>[],
      );

  final List<FavoriteItemEntity> _items;

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {
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

class _FakeVisitedPlacesRepository implements VisitedPlacesRepository {
  _FakeVisitedPlacesRepository({this.items = const <VisitedPlaceEntity>[]});

  final List<VisitedPlaceEntity> items;

  @override
  Future<List<VisitedPlaceEntity>> getVisitedPlaces({
    required String userId,
  }) async {
    return items;
  }

  @override
  Future<VisitedPlaceEntity> recordVisit(VisitedPlaceEntity visit) async {
    return visit;
  }

  @override
  Future<void> removeVisit({
    required String userId,
    required String visitId,
  }) async {}
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
    priceAmount: const Money(minorUnits: 0, currencyCode: 'EUR'),
    isFree: true,
    savedAtUtc: DateTime.parse('2026-04-20T08:00:00Z'),
    targetRoute:
        '${RouteNames.legacyScenarioBuilder}?mood=calm&steps=food_drinks.coffee',
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
      budgetMax: const Money(minorUnits: 1000, currencyCode: 'EUR'),
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
      budgetMax: const Money(minorUnits: 1000, currencyCode: 'EUR'),
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
