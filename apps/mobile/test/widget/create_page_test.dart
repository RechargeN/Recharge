import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/pages/create_page.dart';
import 'package:recharge/features/create/presentation/pages/create_success_page.dart';

import 'widget_test_viewport.dart';

void main() {
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

  fullPageTestWidgets('fast preset fills draft preview and readiness', (
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

    expect(find.text('Fast presets'), findsOneWidget);
    expect(find.text('Publish readiness'), findsOneWidget);
    expect(find.text('Listing preview'), findsOneWidget);

    await tester.tap(find.text('Calm walk'));
    await tester.pumpAndSettle();

    expect(createController.state.draft.objectType, CreateObjectType.activity);
    expect(createController.state.draft.mainCategory, 'wellness_recharge');
    expect(createController.state.draft.subcategory, 'calm_walk');
    expect(createController.state.draft.title, 'Calm walk in Rezekne');
    expect(createController.state.draft.city, 'Rezekne');
    expect(createController.state.draft.media.coverImage, isNotEmpty);
    expect(createController.state.draft.startDateTimeUtc, isNotNull);

    expect(find.text('Calm walk in Rezekne'), findsWidgets);
    expect(find.text('Publishable'), findsOneWidget);
    expect(find.text('6/6 ready'), findsOneWidget);
  });

  fullPageTestWidgets('create hub switches all taxonomy create block cards', (
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

    const Map<String, CreateObjectType> expectedTypes =
        <String, CreateObjectType>{
          'Event': CreateObjectType.event,
          'Recharge activity': CreateObjectType.activity,
          'Route': CreateObjectType.route,
          'Place': CreateObjectType.place,
          'Bookable session': CreateObjectType.session,
          'Quick plan': CreateObjectType.quickPlan,
          'Find people': CreateObjectType.findPeople,
          'Class / workshop': CreateObjectType.classWorkshop,
          'Rental / equipment': CreateObjectType.rental,
          'Collection / guide': CreateObjectType.collection,
        };

    for (final MapEntry<String, CreateObjectType> entry
        in expectedTypes.entries) {
      await tester.scrollPageUntilVisible(
        find.text(entry.key).first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(entry.key).first);
      await tester.pumpAndSettle();

      expect(createController.state.draft.objectType, entry.value);
    }
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

  fullPageTestWidgets('success hub opens published scenario route actions', (
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
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    createController.updateTitle('Calm recharge route');
    createController.applyTaxonomySelection(
      mainCategory: 'travel_tours',
      subcategory: 'walking_tour',
    );
    createController.updateCity('Rezekne');
    createController.updateVenueName('Old town');
    createController.updateShortDescription('2 stops · 90 min · 1.4 km');
    createController.updateFullDescription(
      'Seeded from scenario route. Original context: Calm route with 2 stops. '
      'Route steps: food_drinks.coffee,wellness_recharge.calm_walk. '
      'Review capacity, schedule, booking, and moderation details before publishing.',
    );
    createController.updateCoverImage(
      'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
    );
    createController.updateIsFree(true);
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
                path: RouteNames.scenarioBuilder,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Builder page'),
                      Text(state.uri.queryParameters['mode'] ?? 'no-mode'),
                      Text(state.uri.queryParameters['mood'] ?? ''),
                      Text(state.uri.queryParameters['duration'] ?? ''),
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
                      Text(state.uri.queryParameters['duration'] ?? ''),
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

    expect(find.text('Published route'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Calm walk'), findsOneWidget);

    await tester.tap(find.text('Edit route'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('no-mode'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('Calm recharge route'), findsOneWidget);
    expect(
      find.text('food_drinks.coffee,wellness_recharge.calm_walk'),
      findsOneWidget,
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route map'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('Calm recharge route'), findsOneWidget);
    expect(
      find.text('food_drinks.coffee,wellness_recharge.calm_walk'),
      findsOneWidget,
    );
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
      );
      await createController.ensureLoaded(
        userId: 'u',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
      );
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
        capabilities: <String>['create.event', 'create.place'],
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
