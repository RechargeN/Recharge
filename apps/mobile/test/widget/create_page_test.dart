import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/app/application/planning_conversion_providers.dart';
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
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/scenario_conversion_handoff_store.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/pages/create_hub_page.dart';
import 'package:recharge/features/create/presentation/pages/create_page.dart';
import 'package:recharge/features/create/presentation/pages/create_success_page.dart';

import '../support/event_create_test_support.dart';
import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets(
    'accepts converted Scenario handoff without seed rewrite',
    (tester) async {
      final authController = AuthController(
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
        sourceAction: 'handoff',
      );
      final createRepository = _FakeCreateRepository();
      final createController = CreateController(
        loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
        saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
        publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
        analyticsService: _NoopAnalyticsService(),
        eventCreateCoordinator: createTestEventCoordinator(),
        runtimeDefaults: _testCreateDefaults,
      );
      await createController.ensureLoaded(
        userId: 'u',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
      );
      createController.setObjectType(CreateObjectType.scenario);
      final converted = createController.state.draft.copyWith(
        id: 'converted-scenario-1',
        title: 'Expanded evening',
      );
      createController.setObjectType(CreateObjectType.event);
      final ScenarioConversionHandoffStore handoff =
          ScenarioConversionHandoffStore();
      handoff.put(converted);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authControllerProvider.overrideWith((ref) => authController),
            createControllerProvider.overrideWith((ref) => createController),
            scenarioConversionHandoffStoreProvider.overrideWithValue(handoff),
          ],
          child: const MaterialApp(
            home: CreatePage(
              seedParameters: <String, String>{
                'scenarioHandoffId': 'converted-scenario-1',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(createController.state.draft.id, 'converted-scenario-1');
      expect(
        createController.state.draft.objectType,
        CreateObjectType.scenario,
      );
      expect(find.text('Scenario Builder'), findsOneWidget);
      expect(handoff.contains('converted-scenario-1'), isFalse);
    },
  );

  fullPageTestWidgets('shows cover validation error on publish', (
    tester,
  ) async {
    final authController = AuthController(
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

    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
      runtimeDefaults: _testCreateDefaults,
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    createController.setObjectType(CreateObjectType.activity);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          createControllerProvider.overrideWith((ref) => createController),
        ],
        child: const MaterialApp(home: CreatePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.widgetWithText(TextField, 'Title *'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Title *'),
      'Event title',
    );
    await tester.scrollPageUntilVisible(
      find.widgetWithText(TextField, 'Main category *'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Main category *'),
      'wellness',
    );
    await tester.scrollPageUntilVisible(
      find.widgetWithText(TextField, 'City *'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextField, 'City *'), 'Rezekne');
    await tester.scrollPageUntilVisible(
      find.text('Publish'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Cover image обязательна'), findsOneWidget);
  });

  fullPageTestWidgets('taxonomy picker updates draft form fields', (
    tester,
  ) async {
    final authController = AuthController(
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

    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    createController.setObjectType(CreateObjectType.activity);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          createControllerProvider.overrideWith((ref) => createController),
        ],
        child: const MaterialApp(home: CreatePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Scenario taxonomy'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final Finder sportGroup = find.text('Sport');
    await tester.scrollUntilVisible(
      sportGroup,
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('create-taxonomy-group-rail')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(sportGroup);
    await tester.pumpAndSettle();
    await tester.tap(sportGroup);
    await tester.pumpAndSettle();
    expect(find.text('sport.tennis · practice'), findsOneWidget);

    await tester.tap(find.text('Yoga'));
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.widgetWithText(TextField, 'Main category *'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final TextField categoryField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Main category *'),
    );
    final TextField subcategoryField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Subcategory'),
    );

    expect(categoryField.controller?.text, 'sport');
    expect(subcategoryField.controller?.text, 'yoga');
    expect(createController.state.draft.mainCategory, 'sport');
    expect(createController.state.draft.subcategory, 'yoga');
  });

  fullPageTestWidgets('generic visual clutter is absent from Create forms', (
    tester,
  ) async {
    final authController = AuthController(
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

    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          createControllerProvider.overrideWith((ref) => createController),
        ],
        child: const MaterialApp(home: CreatePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fast presets'), findsNothing);
    expect(find.text('Publish readiness'), findsNothing);
    expect(find.text('Listing preview'), findsNothing);
  });

  fullPageTestWidgets('create hub exposes all blocks and opens object page', (
    tester,
  ) async {
    final authController = AuthController(
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

    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );

    final GoRouter router = GoRouter(
      initialLocation: RouteNames.create,
      routes: <RouteBase>[
        GoRoute(
          name: 'create_object',
          path: '${RouteNames.createObject}/:objectTypeId',
          builder: (_, GoRouterState state) => CreatePage(
            initialObjectType: createObjectTypeFromId(
              state.pathParameters['objectTypeId'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.create,
          builder: (_, __) => CreateHubPage(
            isAuthenticated: authController.state.isAuthenticated,
            capabilities:
                authController.state.user?.capabilities ?? const <String>[],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          createControllerProvider.overrideWith((ref) => createController),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    const Map<String, CreateObjectType> expectedTypes =
        <String, CreateObjectType>{
          'Event': CreateObjectType.event,
          'Recharge activity': CreateObjectType.activity,
          'Route': CreateObjectType.route,
          'Place': CreateObjectType.place,
          'Bookable session': CreateObjectType.session,
          'Scenario': CreateObjectType.scenario,
          'Find people': CreateObjectType.findPeople,
          'Class / workshop': CreateObjectType.classWorkshop,
          'Rental / equipment': CreateObjectType.rental,
          'Collection / guide': CreateObjectType.collection,
        };

    for (final MapEntry<String, CreateObjectType> entry
        in expectedTypes.entries) {
      expect(
        find.byKey(ValueKey<String>('create-hub-${entry.value.taxonomyId}')),
        findsOneWidget,
      );
      expect(
        RouteNames.createObjectFor(entry.value.taxonomyId),
        '/create/new/${entry.value.taxonomyId}',
      );
    }

    await tester.tap(find.byKey(const ValueKey<String>('create-hub-scenario')));
    await tester.pumpAndSettle();

    expect(createController.state.draft.objectType, CreateObjectType.scenario);
    expect(find.text('Create Scenario'), findsOneWidget);
    expect(find.text('Create Hub'), findsNothing);
    expect(router.routerDelegate.canPop(), isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Create Hub'), findsOneWidget);
  });

  fullPageTestWidgets('seed parameters prefill a publishable create draft', (
    tester,
  ) async {
    final authController = AuthController(
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

    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          createControllerProvider.overrideWith((ref) => createController),
        ],
        child: const MaterialApp(
          home: CreatePage(
            seedParameters: <String, String>{
              'source': 'saved_search',
              'type': 'event',
              'title': 'Museum ideas',
              'q': 'museum',
              'subtitle': 'Saved condition set',
              'category': 'art',
              'budgetMax': '10',
              'free': '0',
              'city': 'Rezekne',
              'dateFrom': '2026-04-18T10:00:00Z',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final CreateDraftEntity draft = createController.state.draft;
    expect(draft.objectType, CreateObjectType.event);
    expect(draft.title, 'Museum ideas');
    expect(draft.mainCategory, 'art_culture_museums');
    expect(draft.subcategory, 'museum');
    expect(draft.city, 'Rezekne');
    expect(draft.isFree, isFalse);
    expect(draft.basePrice, 10);
    expect(draft.media.coverImage, isNotEmpty);
    expect(
      draft.startDateTimeUtc?.toIso8601String(),
      '2026-04-18T10:00:00.000Z',
    );
    expect(draft.shortDescription, 'Saved condition set');
    expect(draft.fullDescription, contains('museum'));
    expect(find.text('Seeded from saved search'), findsOneWidget);
    expect(find.text('up to 10'), findsOneWidget);
    expect(find.text('Museum ideas'), findsWidgets);
  });

  fullPageTestWidgets('scenario seed preselects walking tour taxonomy', (
    tester,
  ) async {
    final authController = AuthController(
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

    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          createControllerProvider.overrideWith((ref) => createController),
        ],
        child: const MaterialApp(
          home: CreatePage(
            seedParameters: <String, String>{
              'source': 'scenario',
              'type': 'event',
              'title': 'Calm recharge route',
              'subtitle': '2 stops · 90 min · 1.4 km',
              'q': 'Calm route with 2 stops',
              'category': 'scenario',
              'mood': 'calm',
              'duration': '150',
              'free': '1',
              'walking': '1',
              'steps': 'food_drinks.coffee,wellness_recharge.calm_walk',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final CreateDraftEntity draft = createController.state.draft;
    expect(draft.objectType, CreateObjectType.route);
    expect(draft.title, 'Calm recharge route');
    expect(draft.mainCategory, 'travel_tours');
    expect(draft.subcategory, 'walking_tour');
    expect(draft.isFree, isTrue);
    expect(draft.startDateTimeUtc, isNull);
    expect(draft.shortDescription, '2 stops · 90 min · 1.4 km');
    expect(draft.fullDescription, contains('Route steps:'));
    expect(find.text('Seeded from scenario route'), findsOneWidget);
    expect(find.text('Scenario route seed'), findsOneWidget);
    expect(find.text('2 stops'), findsWidgets);
    expect(find.text('Walking'), findsWidgets);
    expect(find.text('150 min'), findsWidgets);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Calm walk'), findsWidgets);
  });

  fullPageTestWidgets('scenario seed actions open builder and map route', (
    tester,
  ) async {
    final authController = AuthController(
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

    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );

    const Map<String, String> seed = <String, String>{
      'source': 'scenario',
      'type': 'event',
      'title': 'Calm recharge route',
      'subtitle': '2 stops · 90 min · 1.4 km',
      'q': 'Calm route with 2 stops',
      'category': 'scenario',
      'mood': 'calm',
      'duration': '150',
      'free': '1',
      'walking': '1',
      'steps': 'food_drinks.coffee,wellness_recharge.calm_walk',
    };

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          createControllerProvider.overrideWith((ref) => createController),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: Uri(
              path: RouteNames.create,
              queryParameters: seed,
            ).toString(),
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) =>
                    CreatePage(seedParameters: state.uri.queryParameters),
              ),
              GoRoute(
                path: RouteNames.scenarioBuilder,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Builder page'),
                      Text(state.uri.queryParameters['mode'] ?? 'no-mode'),
                      Text(state.uri.queryParameters['mood'] ?? ''),
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
                      Text(state.uri.queryParameters['prompt'] ?? ''),
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

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Scenario route seed'), findsOneWidget);

    await tester.tap(find.text('Edit route'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('no-mode'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('Calm route with 2 stops'), findsOneWidget);
    expect(
      find.text('food_drinks.coffee,wellness_recharge.calm_walk'),
      findsOneWidget,
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map route'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('Calm route with 2 stops'), findsOneWidget);
    expect(
      find.text('food_drinks.coffee,wellness_recharge.calm_walk'),
      findsOneWidget,
    );
  });

  test('Route publish fails safely without its publication service', () async {
    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
      capabilities: const <String>['create.route'],
    );
    createController.setObjectType(CreateObjectType.route);
    final published = await createController.publishDraft();

    expect(published, isFalse);
    expect(createController.state.publishedDraft, isNull);
    expect(createController.state.message, contains('Сервис публикации Route'));
    createController.dispose();
  });

  fullPageTestWidgets(
    'success hub shows published draft and opens next steps',
    (tester) async {
      final authController = AuthController(
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

      final createRepository = _FakeCreateRepository();
      final createController = CreateController(
        loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
        saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
        publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
        analyticsService: _NoopAnalyticsService(),
        eventCreateCoordinator: createTestEventCoordinator(),
        runtimeDefaults: _testCreateDefaults,
      );
      await createController.ensureLoaded(
        userId: 'u',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
      );
      createController.setObjectType(CreateObjectType.activity);
      createController.updateTitle('Museum evening route');
      createController.applyTaxonomySelection(
        mainCategory: 'art_culture_museums',
        subcategory: 'museum',
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
            createControllerProvider.overrideWith((ref) => createController),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: RouteNames.createSuccess,
              routes: <RouteBase>[
                GoRoute(
                  path: RouteNames.createSuccess,
                  builder: (context, state) => const CreateSuccessPage(),
                ),
                GoRoute(
                  path: RouteNames.discover,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Home page')),
                ),
                GoRoute(
                  path: RouteNames.profile,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Profile page')),
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
                  path: RouteNames.create,
                  builder: (context, state) =>
                      const Scaffold(body: Text('Create page')),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Sent to moderation'), findsOneWidget);
      expect(find.text('Museum evening route'), findsWidgets);
      expect(find.text('pendingReview'), findsWidgets);
      expect(find.text('Art, culture & museums'), findsOneWidget);
      expect(find.text('Museum'), findsOneWidget);
      expect(find.text('12 EUR'), findsOneWidget);

      await tester.ensureVisible(find.text('Search similar'));
      await tester.tap(find.text('Search similar'));
      await tester.pumpAndSettle();
      expect(find.text('Search page'), findsOneWidget);
      expect(find.text('Museum evening route'), findsOneWidget);
      expect(find.text('art_culture_museums'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Map area'));
      await tester.tap(find.text('Map area'));
      await tester.pumpAndSettle();
      expect(find.text('Map page'), findsOneWidget);
      expect(find.text('Museum evening route'), findsOneWidget);
      expect(find.text('art_culture_museums'), findsOneWidget);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create another'));
      await tester.tap(find.text('Create another'));
      await tester.pumpAndSettle();
      expect(find.text('Create page'), findsOneWidget);
      expect(createController.state.draft.title, isEmpty);
      expect(createController.state.publishedDraft, isNull);
    },
  );
}

const CreateRuntimeDefaults _testCreateDefaults = CreateRuntimeDefaults(
  marketCityId: 'riga',
  timezone: 'Europe/Riga',
  country: 'LV',
  city: 'Riga',
  currency: 'EUR',
);

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
        role: 'creator',
        capabilities: <String>['create.event', 'create.place', 'create.route'],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class _FakeCreateRepository implements CreateRepository {
  CreateDraftEntity? _stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => _stored;

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    final now = DateTime.now().toUtc();
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
