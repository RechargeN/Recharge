import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/di/service_locator.dart';
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
import 'package:recharge/features/discover/application/queries/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_details_usecase.dart';
import 'package:recharge/features/discover/presentation/pages/discover_details_page.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';

import 'widget_test_viewport.dart';

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerSingleton<AnalyticsService>(_NoopAnalyticsService());
    sl.registerFactory<GetDiscoverDetailsUseCase>(
      () => GetDiscoverDetailsUseCase(_FakeDiscoverRepository()),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  fullPageTestWidgets('renders action hub and opens contextual map', (
    tester,
  ) async {
    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Plan this recharge'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Plan this recharge'), findsOneWidget);
    expect(find.text('Build route'), findsOneWidget);
    expect(find.text('Find similar'), findsOneWidget);
    expect(find.text('Create similar'), findsOneWidget);
    expect(find.text('Route from this'), findsOneWidget);
    expect(find.text('Calm walk · Coffee'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('Morning yoga'), findsOneWidget);
    expect(find.text('wellness'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('56.509900'), findsOneWidget);
    expect(find.text('27.333200'), findsOneWidget);
  });

  fullPageTestWidgets('opens scenario search and create actions', (
    tester,
  ) async {
    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Build route'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Build route'));
    await tester.pumpAndSettle();

    expect(find.text('Builder page'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('Morning yoga'), findsOneWidget);
    expect(
      find.text('wellness_recharge.calm_walk,food_drinks.coffee'),
      findsOneWidget,
    );

    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Route map'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Route map'));
    await tester.pumpAndSettle();

    expect(find.text('Map page'), findsOneWidget);
    expect(find.text('scenario'), findsOneWidget);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(
      find.text('wellness_recharge.calm_walk,food_drinks.coffee'),
      findsOneWidget,
    );

    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Find similar'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Find similar'));
    await tester.pumpAndSettle();

    expect(find.text('Search page'), findsOneWidget);
    expect(find.text('Morning yoga'), findsOneWidget);
    expect(find.text('wellness'), findsOneWidget);

    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Create similar'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create similar'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('details'), findsOneWidget);
    expect(find.text('Morning yoga'), findsWidgets);
    expect(find.text('wellness'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2026-04-18T07:00:00.000Z'), findsOneWidget);

    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    await tester.scrollPageUntilVisible(
      find.text('Create route'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create route'));
    await tester.pumpAndSettle();

    expect(find.text('Create page'), findsOneWidget);
    expect(find.text('scenario'), findsWidgets);
    expect(find.text('Morning yoga route'), findsOneWidget);
    expect(find.textContaining('Morning yoga'), findsWidgets);
    expect(find.text('120'), findsOneWidget);
    expect(
      find.text('wellness_recharge.calm_walk,food_drinks.coffee'),
      findsOneWidget,
    );
  });
}

Future<Widget> _detailsApp() async {
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

  final _FakeFavoritesRepository favoritesRepository =
      _FakeFavoritesRepository();
  final FavoritesController favoritesController = FavoritesController(
    getFavoritesUseCase: GetFavoritesUseCase(favoritesRepository),
    addFavoriteUseCase: AddFavoriteUseCase(favoritesRepository),
    removeFavoriteUseCase: RemoveFavoriteUseCase(favoritesRepository),
    analyticsService: _NoopAnalyticsService(),
  );

  return ProviderScope(
    overrides: <Override>[
      authControllerProvider.overrideWith((ref) => authController),
      favoritesControllerProvider.overrideWith((ref) => favoritesController),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '${RouteNames.discoverDetails}/evt_1',
        routes: <RouteBase>[
          GoRoute(
            path: '${RouteNames.discoverDetails}/:itemId',
            builder: (context, state) => DiscoverDetailsPage(
              itemId: state.pathParameters['itemId'] ?? '',
              favoriteApplied: false,
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
                  Text(state.uri.queryParameters['steps'] ?? ''),
                  Text(state.uri.queryParameters['q'] ?? ''),
                  Text(state.uri.queryParameters['category'] ?? ''),
                  Text(state.uri.queryParameters['free'] ?? ''),
                  Text(state.uri.queryParameters['itemLat'] ?? ''),
                  Text(state.uri.queryParameters['itemLng'] ?? ''),
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
            path: RouteNames.search,
            builder: (context, state) => Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('Search page'),
                  Text(state.uri.queryParameters['q'] ?? ''),
                  Text(state.uri.queryParameters['category'] ?? ''),
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
                  Text(state.uri.queryParameters['free'] ?? ''),
                  Text(state.uri.queryParameters['duration'] ?? ''),
                  Text(state.uri.queryParameters['steps'] ?? ''),
                  Text(state.uri.queryParameters['start'] ?? ''),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
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
        role: 'user',
        capabilities: <String>['discover.read', 'favorites.write'],
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
    return _detailsItem();
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    return <DiscoverItemEntity>[_detailsItem()];
  }
}

class _FakeFavoritesRepository implements FavoritesRepository {
  final List<FavoriteItemEntity> _items = <FavoriteItemEntity>[];

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

DiscoverItemEntity _detailsItem() {
  return DiscoverItemEntity(
    id: 'evt_1',
    title: 'Morning yoga',
    subtitle: 'Gentle recharge session',
    city: 'Rezekne',
    category: 'wellness',
    startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
    latitude: 56.5099,
    longitude: 27.3332,
    priceAmount: 0,
    distanceKm: 1.2,
    isFree: true,
    organizerName: 'Recharge Studio',
    organizerHandle: '@recharge',
    venueName: 'Green studio',
    addressLine: 'Atbrivosanas aleja 1',
    participantsCount: 8,
    capacity: 12,
    durationMinutes: 60,
    ctaLabel: 'Join activity',
    highlights: const <String>['Beginner friendly', 'Calm group pace'],
  );
}
