import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/geo/geo_bounds.dart';
import 'package:recharge/core/geo/geo_point.dart';
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
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/published_route_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/repositories/route_safety_reporting_port.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_details_usecase.dart';
import 'package:recharge/features/discover/domain/usecases/submit_route_safety_report_usecase.dart';
import 'package:recharge/features/discover/presentation/pages/discover_details_page.dart';
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

import '../../../widget/widget_test_viewport.dart';

/// Behavioral parity for `DiscoverDetailsPage` after `DTL-FND-01`'s move
/// onto `DetailsShell`/`DetailsRenderer`/`CompatibilityObjectRenderer`.
///
/// `docs/product/DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` file map: "тесты
/// поведенческого паритета: то же содержимое, те же CTA, та же навигация,
/// та же аналитика до/после". `test/widget/discover_details_page_test.dart`
/// already locks the Map/Route-map/Search/Create navigation handoffs; this
/// file covers the content, CTA and analytics paths that file does not —
/// plus the Route-branch (published-route card, safety report dialog) that
/// had no widget-level coverage before this slice either.
void main() {
  setUp(() async {
    _detailsItemForTest = _activityItem();
    await sl.reset();
    sl.registerSingleton<AnalyticsService>(_SpyAnalyticsService());
    sl.registerFactory<GetDiscoverDetailsUseCase>(
      () => GetDiscoverDetailsUseCase(_FakeDiscoverRepository()),
    );
    sl.registerFactory<SubmitRouteSafetyReportUseCase>(
      () => SubmitRouteSafetyReportUseCase(_FakeRouteSafetyReportingPort()),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  fullPageTestWidgets('renders the same hero, summary and info content', (
    tester,
  ) async {
    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    expect(find.text('RECHARGE'), findsOneWidget);
    expect(find.text('Morning yoga'), findsOneWidget);
    expect(find.text('Gentle recharge session'), findsOneWidget);
    expect(find.text('Recharge Studio'), findsOneWidget);
    expect(find.text('Beginner friendly'), findsOneWidget);
    expect(find.text('Green studio, Atbrivosanas aleja 1'), findsOneWidget);
  });

  fullPageTestWidgets(
    'tracks discover_details_load_started then discover_details_viewed',
    (tester) async {
      await tester.pumpWidget(await _detailsApp());
      await tester.pumpAndSettle();

      final _SpyAnalyticsService spy =
          sl<AnalyticsService>() as _SpyAnalyticsService;
      expect(spy.eventNames, contains('discover_details_load_started'));
      expect(spy.eventNames, contains('discover_details_viewed'));
    },
  );

  fullPageTestWidgets('favorite icon toggles and persists via the repository', (
    tester,
  ) async {
    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsWidgets);
    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();

    expect(find.text('Сохранено в избранное'), findsNothing);
    expect(find.byIcon(Icons.favorite), findsWidgets);
  });

  fullPageTestWidgets('share action copies the deep link to the clipboard', (
    tester,
  ) async {
    final List<MethodCall> clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardCalls.add(call);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(await _detailsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Ссылка скопирована'), findsOneWidget);
    expect(clipboardCalls, hasLength(1));
    // DTL-LINK-01: the self-link is now the typed canonical form, not the
    // pre-DTL-LINK-01 untyped `recharge://discover/details/{id}`.
    expect(
      clipboardCalls.single.arguments['text'],
      'recharge://discover/details/activity/evt_1',
    );
  });

  fullPageTestWidgets(
    'CTA tap disables the button, shows the same label and tracks it',
    (tester) async {
      await tester.pumpWidget(await _detailsApp());
      await tester.pumpAndSettle();
      // 'Join activity' renders twice (action hub CTA + sticky bottom bar
      // CTA, both showing the same label by design) — `.first` keeps the
      // scroll/tap finder single-element, as `scrollUntilVisible` requires.
      await tester.scrollPageUntilVisible(
        find.text('Join activity').first,
        260,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Join activity').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Join activity: заявка отправлена'),
        findsOneWidget,
      );
      final _SpyAnalyticsService spy =
          sl<AnalyticsService>() as _SpyAnalyticsService;
      expect(spy.eventNames, contains('discover_details_cta_clicked'));

      final FilledButton bottomBarButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Заявка отправлена'),
      );
      expect(bottomBarButton.onPressed, isNull);
    },
  );

  fullPageTestWidgets(
    'a published-route item dispatches to RouteDetailsRenderer (DTL-RTE-01) '
    'and submits a safety report through the same dialog flow',
    (tester) async {
      _detailsItemForTest = _routeItem();
      await tester.pumpWidget(await _detailsApp());
      await tester.pumpAndSettle();

      await tester.scrollPageUntilVisible(
        find.text('Route details'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Route details'), findsOneWidget);
      expect(find.text('Walking'), findsWidgets);

      await tester.tap(find.text('Сообщить о проблеме на маршруте'));
      await tester.pumpAndSettle();

      expect(find.text('Проблема на маршруте'), findsOneWidget);
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(
        find.text('Спасибо. Сообщение передано на проверку.'),
        findsOneWidget,
      );
      final _SpyAnalyticsService spy =
          sl<AnalyticsService>() as _SpyAnalyticsService;
      expect(spy.eventNames, contains('route_safety_report_submitted'));
      final _FakeRouteSafetyReportingPort port =
          _fakeRouteSafetyReportingPort!;
      expect(port.submittedReasonCodes, contains('trail_closed'));
    },
  );
}

DiscoverItemEntity _detailsItemForTest = _activityItem();
_FakeRouteSafetyReportingPort? _fakeRouteSafetyReportingPort;

Future<Widget> _detailsApp() async {
  final AuthController authController = AuthController(
    signInUseCase: SignInUseCase(_NoopAuthRepository()),
    restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
    signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
    getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
    analyticsService: _SpyAnalyticsService(),
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
    analyticsService: _SpyAnalyticsService(),
  );
  final VisitedPlacesController visitedController = VisitedPlacesController(
    getVisitedPlacesUseCase: GetVisitedPlacesUseCase(
      _FakeVisitedPlacesRepository(),
    ),
    analyticsService: _SpyAnalyticsService(),
  );

  return ProviderScope(
    overrides: <Override>[
      authControllerProvider.overrideWith((ref) => authController),
      favoritesControllerProvider.overrideWith((ref) => favoritesController),
      visitedPlacesControllerProvider.overrideWith(
        (ref) => visitedController,
      ),
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
            builder: (context, state) => const Scaffold(
              body: Text('Map page'),
            ),
          ),
          GoRoute(
            path: RouteNames.search,
            builder: (context, state) => const Scaffold(
              body: Text('Search page'),
            ),
          ),
          GoRoute(
            path: RouteNames.create,
            builder: (context, state) => const Scaffold(
              body: Text('Create page'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SpyAnalyticsService implements AnalyticsService {
  final List<String> eventNames = <String>[];

  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {
    eventNames.add(eventName);
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
    return _detailsItemForTest;
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    return <DiscoverItemEntity>[_detailsItemForTest];
  }
}

class _FakeRouteSafetyReportingPort implements RouteSafetyReportingPort {
  _FakeRouteSafetyReportingPort() {
    _fakeRouteSafetyReportingPort = this;
  }

  final List<String> submittedReasonCodes = <String>[];

  @override
  Future<void> submit({
    required String routeId,
    required String reporterId,
    required String reasonCode,
    required DiscoverRouteSafetySeverity severity,
    String? safeNote,
  }) async {
    submittedReasonCodes.add(reasonCode);
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

class _FakeVisitedPlacesRepository implements VisitedPlacesRepository {
  final List<VisitedPlaceEntity> items = <VisitedPlaceEntity>[];

  @override
  Future<List<VisitedPlaceEntity>> getVisitedPlaces({
    required String userId,
  }) async {
    return List<VisitedPlaceEntity>.from(items);
  }

  @override
  Future<VisitedPlaceEntity> recordVisit(VisitedPlaceEntity visit) async {
    items.add(visit);
    return visit;
  }

  @override
  Future<void> removeVisit({
    required String userId,
    required String visitId,
  }) async {
    items.removeWhere((VisitedPlaceEntity item) => item.id == visitId);
  }
}

DiscoverItemEntity _activityItem() {
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
    objectKind: DiscoverObjectKind.activity,
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

DiscoverItemEntity _routeItem() {
  return DiscoverItemEntity(
    id: 'route_1',
    title: 'Forest walking route',
    subtitle: 'A continuous trail through the forest.',
    city: 'Riga',
    category: 'outdoor_nature_walking',
    startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
    latitude: 56.9496,
    longitude: 24.1052,
    priceAmount: 0,
    distanceKm: 0.4,
    isFree: true,
    objectKind: DiscoverObjectKind.route,
    ctaLabel: 'View route',
    publishedRoute: PublishedRouteDiscoveryEntity(
      routeId: 'route_1',
      versionId: 'v1',
      geometryHash: 'hash',
      contentHash: 'content-v1',
      title: 'Forest walking route',
      subtitle: 'A continuous trail through the forest.',
      city: 'Riga',
      marketCityId: 'riga',
      timezoneId: 'Europe/Riga',
      categoryId: 'outdoor_nature_walking',
      subcategoryId: 'walking_route',
      coverImage: 'asset://route.jpg',
      publisherName: 'Recharge',
      startPoint: const GeoPoint(latitude: 56.9496, longitude: 24.1052),
      bounds: const GeoBounds(
        southwest: GeoPoint(latitude: 56.9496, longitude: 24.1052),
        northeast: GeoPoint(latitude: 56.9520, longitude: 24.1150),
      ),
      overviewEncodedPolyline: '_p~iF~ps|U_ulLnnqC',
      fullEncodedPolyline: '_p~iF~ps|U_ulLnnqC',
      encodingPrecision: 5,
      distanceMeters: 4200,
      durationSeconds: 2700,
      routingProfileId: 'walking',
      difficultyId: 'easy.v1',
      demoOnly: true,
      searchTokens: const <String>['forest', 'walking', 'route'],
      attributions: const <String>['OpenStreetMap contributors'],
      publishedAtUtc: DateTime.utc(2026, 7, 25, 10),
    ),
  );
}
