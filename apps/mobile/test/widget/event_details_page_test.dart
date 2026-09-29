import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/event_details_page.dart';
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
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/event_occurrence.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/publisher_verification_display_state.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';

import 'widget_test_viewport.dart';

void main() {
  late _SpyAnalyticsService analytics;

  setUp(() async {
    await sl.reset();
    analytics = _SpyAnalyticsService();
    _testFavoritesRepository = _FakeFavoritesRepository();
    sl.registerSingleton<AnalyticsService>(analytics);
    sl.registerSingleton<TimezoneRepository>(TimezoneRepositoryImpl());
  });

  tearDown(() async {
    await sl.reset();
  });

  fullPageTestWidgets(
    'Save and canonical Share work through the real EventDetailsPage',
    (WidgetTester tester) async {
      final List<MethodCall> clipboardCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            if (call.method == 'Clipboard.setData') {
              clipboardCalls.add(call);
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(await _app());
      await tester.pumpAndSettle();

      expect(analytics.eventNames, contains('discover_details_viewed'));
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(_testFavoritesRepository.items.single.id, 'evt-1');
      expect(_testFavoritesRepository.items.single.startsAtUtc, _startAtUtc);

      await tester.tap(find.byIcon(Icons.ios_share_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Поделиться'));
      await tester.pumpAndSettle();

      expect(clipboardCalls, hasLength(1));
      expect(
        clipboardCalls.single.arguments['text'],
        'recharge://discover/details/event/evt-1',
      );
    },
  );

  fullPageTestWidgets('Map receives the Event projection coordinates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Показать на карте'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Показать на карте'));
    await tester.pumpAndSettle();

    expect(find.text('Map destination'), findsOneWidget);
    expect(find.text('item=evt-1;lat=56.950000;lng=24.100000'), findsOneWidget);
  });

  fullPageTestWidgets('verified page organizer opens its public profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();
    await tester.scrollPageUntilVisible(
      find.text('Recharge Events'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Recharge Events'));
    await tester.pumpAndSettle();

    expect(find.text('Organizer page page-1'), findsOneWidget);
  });

  fullPageTestWidgets('free CTA is an honest acknowledgement and is tracked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Присоединиться').last);
    await tester.pumpAndSettle();

    expect(find.text('Интерес к событию отмечен'), findsOneWidget);
    expect(analytics.eventNames, contains('discover_details_cta_clicked'));
  });
}

final DateTime _startAtUtc = DateTime.utc(2026, 9, 5, 15);

Future<Widget> _app() async {
  final AuthController authController = AuthController(
    signInUseCase: SignInUseCase(_FakeAuthRepository()),
    restoreSessionUseCase: RestoreSessionUseCase(_FakeAuthRepository()),
    signOutUseCase: SignOutUseCase(_FakeAuthRepository()),
    getCurrentUserUseCase: GetCurrentUserUseCase(_FakeAuthRepository()),
    analyticsService: sl<AnalyticsService>(),
  );
  await authController.signIn(
    email: 'user@example.com',
    password: 'password123',
    sourceScreen: 'test',
    sourceAction: 'seed',
  );
  final FavoritesController favoritesController = FavoritesController(
    getFavoritesUseCase: GetFavoritesUseCase(_testFavoritesRepository),
    addFavoriteUseCase: AddFavoriteUseCase(_testFavoritesRepository),
    removeFavoriteUseCase: RemoveFavoriteUseCase(_testFavoritesRepository),
    analyticsService: sl<AnalyticsService>(),
  );

  final GoRouter router = GoRouter(
    initialLocation: '/event',
    routes: <RouteBase>[
      GoRoute(
        path: '/event',
        builder: (BuildContext context, GoRouterState state) =>
            EventDetailsPage(projection: _event()),
      ),
      GoRoute(
        path: RouteNames.discoverMap,
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Text(
            'item=${state.uri.queryParameters['itemId']};'
            'lat=${state.uri.queryParameters['itemLat']};'
            'lng=${state.uri.queryParameters['itemLng']}',
          ),
        ),
      ),
      GoRoute(
        path: '${RouteNames.publicProfessionalPagesById}/:pageId',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Text('Organizer page ${state.pathParameters['pageId']}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: <Override>[
      authControllerProvider.overrideWith((ref) => authController),
      favoritesControllerProvider.overrideWith((ref) => favoritesController),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

late _FakeFavoritesRepository _testFavoritesRepository;

PublishedEventDiscoveryEntity _event() => PublishedEventDiscoveryEntity(
  eventId: 'evt-1',
  publisherId: 'page-1',
  publisherType: 'page',
  publisherName: 'Recharge Events',
  publisherHandle: '@recharge-events',
  publisherVerification: PublisherVerificationDisplayState.verifiedPage,
  title: 'Riga sunset meetup',
  subtitle: 'A relaxed evening together',
  fullDescription: 'Meet, move, and recharge together.',
  category: 'community',
  city: 'Riga',
  venueName: 'Recharge Garden',
  addressLine: 'Garden Street 1',
  latitude: 56.95,
  longitude: 24.1,
  distanceKm: 1.2,
  priceAmount: 0,
  isFree: true,
  currencyCode: 'EUR',
  participantsCount: 12,
  durationMinutes: 90,
  scheduleMode: EventScheduleMode.oneTime,
  occurrences: <EventOccurrence>[
    EventOccurrence(
      id: 'occ-1',
      startAtUtc: _startAtUtc,
      endAtUtc: DateTime.utc(2026, 9, 5, 16, 30),
      status: EventOccurrenceStatus.scheduled,
    ),
  ],
  displayOccurrenceId: 'occ-1',
  timezoneId: 'Europe/Riga',
  publishedAtUtc: DateTime.utc(2026, 8, 30),
);

class _SpyAnalyticsService implements AnalyticsService {
  final List<String> eventNames = <String>[];

  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {
    eventNames.add(eventName);
  }
}

class _FakeAuthRepository implements AuthRepository {
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
  }) async => AuthResultEntity(
    session: AuthSessionEntity(
      accessToken: 'access',
      refreshToken: 'refresh',
      sessionId: 'session',
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    ),
    user: const AuthUserEntity(
      id: 'user-1',
      email: 'user@example.com',
      role: 'user',
      capabilities: <String>['discover.read', 'favorites.write'],
      profileStatus: 'active',
    ),
  );

  @override
  Future<void> signOut() async {}
}

class _FakeFavoritesRepository implements FavoritesRepository {
  final List<FavoriteItemEntity> items = <FavoriteItemEntity>[];

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async => items.add(item);

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async =>
      List<FavoriteItemEntity>.from(items);

  @override
  Future<void> removeFavorite(String itemId) async {
    items.removeWhere((FavoriteItemEntity item) => item.id == itemId);
  }
}
