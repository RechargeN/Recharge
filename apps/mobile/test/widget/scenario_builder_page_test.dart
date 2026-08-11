import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/money_test_values.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/app/application/planning_conversion_providers.dart';
import 'package:recharge/app/adapters/legacy_quick_plan_conversion_adapter.dart';
import 'package:recharge/core/id/id_generator.dart';
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
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/quick_plan_conversion_coordinator.dart';
import 'package:recharge/features/create/application/scenario_conversion_handoff_store.dart';
import 'package:recharge/features/create/data/datasources/quick_plan_conversion_memory_datasource.dart';
import 'package:recharge/features/create/domain/usecases/expand_quick_plan_to_scenario_usecase.dart';
import 'package:recharge/features/scenarios/presentation/pages/scenario_builder_page.dart';

import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets('previews one-way Expand to Scenario losses', (
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
      email: 'user@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'expand',
    );
    await tester.pumpWidget(
      _scenarioProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
        ],
        child: const MaterialApp(
          home: ScenarioBuilderPage(
            seedParameters: <String, String>{'preview': '1'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.byKey(const Key('quick-plan-expand-to-scenario')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('quick-plan-expand-to-scenario')));
    await tester.pumpAndSettle();

    expect(find.text('Expand to Scenario'), findsWidgets);
    expect(find.textContaining('new independent Scenario'), findsOneWidget);
    expect(find.textContaining('private custom locations'), findsOneWidget);
    expect(find.byKey(const Key('confirm-expand-to-scenario')), findsOneWidget);
  });

  fullPageTestWidgets('expands Quick Plan through an id-only Create handoff', (
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
      email: 'user@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'expand-flow',
    );
    final InMemoryQuickPlanConversionSource source =
        InMemoryQuickPlanConversionSource();
    final _TestIdGenerator ids = _TestIdGenerator();
    final ScenarioConversionHandoffStore handoff =
        ScenarioConversionHandoffStore();
    final QuickPlanConversionCoordinator coordinator =
        QuickPlanConversionCoordinator(
          expand: ExpandQuickPlanToScenarioUseCase(
            source: source,
            idGenerator: ids,
          ),
          idGenerator: ids,
          runtimeDefaults: const CreateRuntimeDefaults(
            marketCityId: 'riga',
            timezone: 'Europe/Riga',
            country: 'LV',
            city: 'Riga',
            currency: 'EUR',
          ),
        );
    await tester.pumpWidget(
      _scenarioProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          quickPlanConversionSourceProvider.overrideWithValue(source),
          legacyQuickPlanConversionAdapterProvider.overrideWithValue(
            const LegacyQuickPlanConversionAdapter(),
          ),
          quickPlanConversionCoordinatorProvider.overrideWithValue(coordinator),
          scenarioConversionHandoffStoreProvider.overrideWithValue(handoff),
          planningCreateRuntimeDefaultsProvider.overrideWithValue(
            const CreateRuntimeDefaults(
              marketCityId: 'riga',
              timezone: 'Europe/Riga',
              country: 'LV',
              city: 'Riga',
              currency: 'EUR',
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '${RouteNames.scenarioBuilder}?preview=1',
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.scenarioBuilder,
                builder: (context, state) => ScenarioBuilderPage(
                  seedParameters: state.uri.queryParameters,
                ),
              ),
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Converted Create page'),
                      Text(
                        state.uri.queryParameters['scenarioHandoffId'] ?? '',
                      ),
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
    await tester.scrollPageUntilVisible(
      find.byKey(const Key('quick-plan-expand-to-scenario')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('quick-plan-expand-to-scenario')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-expand-to-scenario')));
    await tester.pumpAndSettle();

    expect(find.text('Converted Create page'), findsOneWidget);
    final Finder handoffText = find.textContaining('flow-id-');
    expect(handoffText, findsOneWidget);
    final String handoffId = tester.widget<Text>(handoffText).data!;
    expect(handoff.contains(handoffId), isTrue);
  });

  fullPageTestWidgets('opens a quick plan in preview-first mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: const MaterialApp(
          home: ScenarioBuilderPage(
            seedParameters: <String, String>{
              'preview': '1',
              'title': 'After work',
              'mood': 'calm',
              'duration': '120',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My plan'), findsOneWidget);
    expect(find.text('After work'), findsOneWidget);
    expect(find.text('Your route'), findsOneWidget);
    expect(find.byKey(const Key('scenario-preview-edit')), findsOneWidget);
    expect(find.text('Builder controls'), findsNothing);

    await tester.tap(find.byKey(const Key('scenario-preview-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Scenario Builder'), findsOneWidget);
    expect(find.text('Ready route ideas'), findsOneWidget);
  });

  fullPageTestWidgets('renders scenario builder and updates mood', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: const MaterialApp(home: ScenarioBuilderPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scenario Builder'), findsOneWidget);
    expect(find.text('Build a recharge route'), findsOneWidget);
    expect(find.text('Slow coffee start'), findsOneWidget);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();

    expect(find.text('Tennis warm-up'), findsOneWidget);
    expect(find.text('Tennis'), findsOneWidget);
  });

  fullPageTestWidgets('applies seed parameters from smart search handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: const MaterialApp(
          home: ScenarioBuilderPage(
            seedParameters: <String, String>{
              'mood': 'active',
              'duration': '90',
              'walking': '1',
              'prompt': 'tennis near me',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active plan with 1 stops'), findsOneWidget);
    expect(find.text('Intent: tennis near me'), findsOneWidget);
    expect(find.text('Tennis warm-up'), findsOneWidget);
  });

  fullPageTestWidgets('applies ready route template to the draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: const MaterialApp(home: ScenarioBuilderPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready route ideas'), findsOneWidget);
    expect(find.text('Coffee reset'), findsOneWidget);
    expect(find.text('Social evening'), findsOneWidget);

    await tester.tap(find.byTooltip('Apply Social evening template'));
    await tester.pumpAndSettle();

    expect(find.text('Social plan with 2 stops'), findsOneWidget);
    expect(find.text('Intent: social evening near me'), findsOneWidget);
    expect(find.text('Board game table'), findsOneWidget);
    expect(find.text('Afterwork drinks'), findsWidgets);
    expect(find.text('Social evening applied'), findsOneWidget);
    expect(find.text('Applied'), findsOneWidget);
  });

  fullPageTestWidgets('restores exact saved scenario steps from seed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: const MaterialApp(
          home: ScenarioBuilderPage(
            seedParameters: <String, String>{
              'mood': 'calm',
              'steps': 'wellness_recharge.calm_walk',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calm city walk'), findsOneWidget);
    expect(find.text('Slow coffee start'), findsOneWidget);
    expect(find.text('Calm plan with 1 stops'), findsOneWidget);
  });

  fullPageTestWidgets('opens map with scenario route parameters', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.scenarioBuilder,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.scenarioBuilder,
                builder: (context, state) => const ScenarioBuilderPage(),
              ),
              GoRoute(
                path: RouteNames.discoverMap,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Map route page'),
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

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();

    expect(find.text('Map route page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);
  });

  fullPageTestWidgets('opens map with applied route template parameters', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.scenarioBuilder,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.scenarioBuilder,
                builder: (context, state) => const ScenarioBuilderPage(),
              ),
              GoRoute(
                path: RouteNames.discoverMap,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Map route page'),
                      Text(state.uri.queryParameters['mode'] ?? ''),
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(state.uri.queryParameters['prompt'] ?? ''),
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

    await tester.tap(find.byTooltip('Apply Social evening template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();

    expect(find.text('Map route page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('social'), findsOneWidget);
    expect(find.text('social evening near me'), findsOneWidget);
    expect(find.textContaining('games_indoor.board_games'), findsOneWidget);
    expect(
      find.textContaining('music_nightlife.afterwork_drinks'),
      findsOneWidget,
    );
  });

  fullPageTestWidgets('optimizes route fit before opening map', (tester) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation:
                '${RouteNames.scenarioBuilder}?mood=social&duration=90'
                '&free=1&walking=1'
                '&steps=games_indoor.board_games,'
                'music_nightlife.afterwork_drinks',
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.scenarioBuilder,
                builder: (context, state) => ScenarioBuilderPage(
                  seedParameters: state.uri.queryParameters,
                ),
              ),
              GoRoute(
                path: RouteNames.discoverMap,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Map route page'),
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

    expect(find.text('Route fit'), findsOneWidget);
    expect(find.text('Needs tuning'), findsOneWidget);
    expect(find.text('Trim about 35 min'), findsOneWidget);
    expect(find.text('Remove paid stops for free-only mode'), findsOneWidget);

    await tester.scrollPageUntilVisible(
      find.text('Optimize'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Optimize'));
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Afterwork drinks'), findsNothing);

    await tester.scrollPageUntilVisible(
      find.text('Map route'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Map route'));
    await tester.pumpAndSettle();

    expect(find.text('Map route page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.textContaining('games_indoor.board_games'), findsOneWidget);
    expect(
      find.textContaining('music_nightlife.afterwork_drinks'),
      findsNothing,
    );
  });

  fullPageTestWidgets('opens create from route fit panel', (tester) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.scenarioBuilder,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.scenarioBuilder,
                builder: (context, state) => const ScenarioBuilderPage(),
              ),
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Create page'),
                      Text(state.uri.queryParameters['source'] ?? ''),
                      Text(state.uri.queryParameters['category'] ?? ''),
                      Text(state.uri.queryParameters['mood'] ?? ''),
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

    await tester.scrollPageUntilVisible(
      find.byTooltip('Publish optimized route'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Publish optimized route'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('scenario'), findsWidgets);
    expect(find.text('calm'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
  });

  fullPageTestWidgets('opens create with scenario route seed parameters', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.scenarioBuilder,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.scenarioBuilder,
                builder: (context, state) => const ScenarioBuilderPage(),
              ),
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Create page'),
                      Text(state.uri.queryParameters['source'] ?? ''),
                      Text(state.uri.queryParameters['title'] ?? ''),
                      Text(state.uri.queryParameters['category'] ?? ''),
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publish route'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('scenario'), findsWidgets);
    expect(find.text('Calm recharge route'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);
  });

  fullPageTestWidgets(
    'builds route from saved conditions and opens map/create',
    (tester) async {
      await _pumpScenarioIntentHarness(
        tester,
        savedSearches: <SavedSearchEntity>[_savedSearch()],
        smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
      );

      expect(find.text('Build from saved intent'), findsOneWidget);
      expect(find.text('Museum ideas'), findsOneWidget);

      await _tapScrollableTooltip(tester, 'Apply saved conditions to builder');

      expect(find.textContaining('Social plan with'), findsOneWidget);
      expect(find.textContaining('Intent: museum'), findsOneWidget);

      await _pumpScenarioIntentHarness(
        tester,
        savedSearches: <SavedSearchEntity>[_savedSearch()],
        smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
      );
      await _tapScrollableTooltip(tester, 'Open saved conditions on map');

      expect(find.text('Map route page'), findsOneWidget);
      expect(find.text('museum'), findsOneWidget);
      expect(find.text('art'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('5000'), findsOneWidget);

      await _pumpScenarioIntentHarness(
        tester,
        savedSearches: <SavedSearchEntity>[_savedSearch()],
        smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
      );
      await _tapScrollableTooltip(
        tester,
        'Create listing from saved conditions',
      );

      expect(find.text('Create page'), findsOneWidget);
      expect(find.text('saved_search'), findsOneWidget);
      expect(find.text('Museum ideas'), findsOneWidget);
      expect(find.text('museum'), findsOneWidget);
      expect(find.text('art'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('event'), findsOneWidget);
    },
  );

  fullPageTestWidgets('builds route from smart search and opens map/create', (
    tester,
  ) async {
    await _pumpScenarioIntentHarness(
      tester,
      savedSearches: <SavedSearchEntity>[_savedSearch()],
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
    );

    expect(find.text('museum today under 10'), findsOneWidget);

    await _tapScrollableTooltip(tester, 'Apply smart search to builder');

    expect(find.textContaining('Social plan with'), findsOneWidget);
    expect(find.text('Intent: museum today under 10'), findsOneWidget);

    await _pumpScenarioIntentHarness(
      tester,
      savedSearches: <SavedSearchEntity>[_savedSearch()],
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
    );
    await _tapScrollableTooltip(tester, 'Open smart search on map');

    expect(find.text('Map route page'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);

    await _pumpScenarioIntentHarness(
      tester,
      savedSearches: <SavedSearchEntity>[_savedSearch()],
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartSearch()],
    );
    await _tapScrollableTooltip(tester, 'Create listing from smart search');

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('smart_search'), findsOneWidget);
    expect(find.text('Museum'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
  });

  fullPageTestWidgets('keeps smart route intent from builder saved launcher', (
    tester,
  ) async {
    await _pumpScenarioIntentHarness(
      tester,
      savedSearches: const <SavedSearchEntity>[],
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartRouteSearch()],
    );

    const String prompt =
        'build a free calm walking route for 2 hours with coffee and park near 5 km';

    expect(find.text('Build from saved intent'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);
    expect(find.text('Smart route'), findsOneWidget);
    expect(find.text('120 min'), findsWidgets);
    expect(find.text('2 stops'), findsOneWidget);

    await _tapScrollableTooltip(tester, 'Apply smart search to builder');

    expect(find.textContaining('Calm plan with'), findsOneWidget);
    expect(find.textContaining('Intent: build a free calm'), findsOneWidget);
    expect(find.textContaining('Coffee'), findsWidgets);

    await _pumpScenarioIntentHarness(
      tester,
      savedSearches: const <SavedSearchEntity>[],
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartRouteSearch()],
    );
    await _tapScrollableTooltip(tester, 'Open smart search on map');

    expect(find.text('Map route page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.textContaining('wellness_recharge.calm_walk'), findsOneWidget);

    await _pumpScenarioIntentHarness(
      tester,
      savedSearches: const <SavedSearchEntity>[],
      smartSearchHistory: <SmartSearchHistoryEntity>[_smartRouteSearch()],
    );
    await _tapScrollableTooltip(tester, 'Create listing from smart search');

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('scenario'), findsWidgets);
    expect(find.text('Calm recharge route'), findsOneWidget);
    expect(find.text(prompt), findsOneWidget);
    expect(find.text('event'), findsOneWidget);
    expect(find.textContaining('food_drinks.coffee'), findsOneWidget);
  });

  fullPageTestWidgets('edits route steps with suggestions', (tester) async {
    await tester.pumpWidget(
      _scenarioProviderScope(
        child: const MaterialApp(home: ScenarioBuilderPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Slow coffee start'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove stop').first);
    await tester.pumpAndSettle();

    expect(find.text('Slow coffee start'), findsOneWidget);

    await tester.scrollPageUntilVisible(
      find.text('Suggested stops'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();

    expect(find.text('Slow coffee start'), findsOneWidget);
  });

  fullPageTestWidgets('saves scenario into favorites', (tester) async {
    final AuthController authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'user@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final _FakeFavoritesRepository repository = _FakeFavoritesRepository();
    final FavoritesController favoritesController = FavoritesController(
      getFavoritesUseCase: GetFavoritesUseCase(repository),
      addFavoriteUseCase: AddFavoriteUseCase(repository),
      removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      _scenarioProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          favoritesControllerProvider.overrideWith(
            (ref) => favoritesController,
          ),
        ],
        child: const MaterialApp(home: ScenarioBuilderPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final List<FavoriteItemEntity> saved = await repository.getFavorites();
    expect(saved, hasLength(1));
    expect(saved.single.category, 'scenario');
    expect(saved.single.title, contains('recharge scenario'));
    expect(saved.single.targetRoute, contains('/scenario-builder'));
    expect(saved.single.targetRoute, contains('steps='));
  });
}

Widget _scenarioProviderScope({
  required Widget child,
  DiscoverFeedController? discoverController,
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      discoverFeedControllerProvider.overrideWith(
        (ref) => discoverController ?? _discoverController(),
      ),
      ...overrides,
    ],
    child: child,
  );
}

Future<void> _pumpScenarioIntentHarness(
  WidgetTester tester, {
  required List<SavedSearchEntity> savedSearches,
  required List<SmartSearchHistoryEntity> smartSearchHistory,
}) async {
  await tester.pumpWidget(
    _scenarioProviderScope(
      discoverController: _discoverController(
        savedSearches: savedSearches,
        smartSearchHistory: smartSearchHistory,
      ),
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: RouteNames.scenarioBuilder,
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.scenarioBuilder,
              builder: (context, state) => ScenarioBuilderPage(
                seedParameters: state.uri.queryParameters,
              ),
            ),
            GoRoute(
              path: RouteNames.discoverMap,
              builder: (context, state) => Scaffold(
                body: Column(
                  children: <Widget>[
                    const Text('Map route page'),
                    Text(state.uri.queryParameters['mode'] ?? ''),
                    Text(state.uri.queryParameters['mood'] ?? ''),
                    Text(state.uri.queryParameters['duration'] ?? ''),
                    Text(state.uri.queryParameters['steps'] ?? ''),
                    Text(state.uri.queryParameters['q'] ?? ''),
                    Text(state.uri.queryParameters['category'] ?? ''),
                    Text(state.uri.queryParameters['budgetMax'] ?? ''),
                    Text(state.uri.queryParameters['radius'] ?? ''),
                    Text(state.uri.queryParameters['free'] ?? ''),
                    Text(state.uri.queryParameters['unlimited'] ?? ''),
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
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapScrollableTooltip(WidgetTester tester, String tooltip) async {
  final Finder target = find.byTooltip(tooltip);
  await tester.scrollPageUntilVisible(
    target,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
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
      price: testZeroEur,
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
        capabilities: <String>['favorites.write'],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class _TestIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => 'flow-id-${_value++}';
}

class _FakeFavoritesRepository implements FavoritesRepository {
  final List<FavoriteItemEntity> _items = <FavoriteItemEntity>[];

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {
    _items.removeWhere((FavoriteItemEntity current) => current.id == item.id);
    _items.insert(0, item);
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
