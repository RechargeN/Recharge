import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/scenario_object_intake_config.dart';
import 'package:recharge/app/application/scenario_object_intake_providers.dart';
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
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/discover/presentation/pages/discover_map_page.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/favorites_providers.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';

void main() {
  testWidgets('Map exposes single intake and ordered selection tray', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 1200)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(await _mapApp());
    await tester.pumpAndSettle();
    await tester.drag(find.text('Map results'), const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Map item 1').last);
    await tester.pump();
    expect(find.text('Add to Scenario'), findsOneWidget);

    await tester.tap(find.byTooltip('Select for Scenario'));
    await tester.pump();
    await tester.tap(find.text('Map item 2').last);
    await tester.pump();
    await tester.tap(find.text('Map item 1').last);
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Map item 2'), findsWidgets);
    expect(find.text('Map item 1'), findsWidgets);
    expect(find.text('Review'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('2 selected'), findsNothing);
  });

  testWidgets('Map intake flag hides single and multi actions', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 1200)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      await _mapApp(
        config: const ScenarioObjectIntakeConfig(mapEnabled: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Select for Scenario'), findsNothing);
    await tester.drag(find.text('Map results'), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map item 1').last);
    await tester.pump();
    expect(find.text('Add to Scenario'), findsNothing);
  });
}

Future<Widget> _mapApp({ScenarioObjectIntakeConfig? config}) async {
  final authController = _authController();
  await authController.signIn(
    email: 'user@example.test',
    password: 'password123',
    sourceScreen: 'test',
    sourceAction: 'map_intake',
  );
  final discoverController = DiscoverFeedController(
    getDiscoverFeedUseCase: GetDiscoverFeedUseCase(_DiscoverRepository()),
    discoverPreferencesRepository: _PreferencesRepository(),
    analyticsService: _Analytics(),
  );
  final favoriteRepository = _FavoritesRepository();
  final favoritesController = FavoritesController(
    getFavoritesUseCase: GetFavoritesUseCase(favoriteRepository),
    addFavoriteUseCase: AddFavoriteUseCase(favoriteRepository),
    removeFavoriteUseCase: RemoveFavoriteUseCase(favoriteRepository),
    analyticsService: _Analytics(),
  );
  return ProviderScope(
    overrides: <Override>[
      authControllerProvider.overrideWith((ref) => authController),
      discoverFeedControllerProvider.overrideWith((ref) => discoverController),
      favoritesControllerProvider.overrideWith((ref) => favoritesController),
      if (config != null)
        scenarioObjectIntakeConfigProvider.overrideWithValue(config),
    ],
    child: const MaterialApp(home: DiscoverMapPage()),
  );
}

AuthController _authController() => AuthController(
  signInUseCase: SignInUseCase(_AuthRepository()),
  restoreSessionUseCase: RestoreSessionUseCase(_AuthRepository()),
  signOutUseCase: SignOutUseCase(_AuthRepository()),
  getCurrentUserUseCase: GetCurrentUserUseCase(_AuthRepository()),
  analyticsService: _Analytics(),
);

class _AuthRepository implements AuthRepository {
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
      expiresAtUtc: DateTime.utc(2026, 8, 4),
    ),
    user: const AuthUserEntity(
      id: 'user-1',
      email: 'user@example.test',
      role: 'user',
      capabilities: <String>[],
      profileStatus: 'active',
    ),
  );

  @override
  Future<void> signOut() async {}
}

class _DiscoverRepository implements DiscoverRepository {
  final items = <DiscoverItemEntity>[_item(1), _item(2), _item(3)];

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) async =>
      items.singleWhere((item) => item.id == itemId);

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async => items;
}

DiscoverItemEntity _item(int index) => DiscoverItemEntity(
  id: 'map-$index',
  title: 'Map item $index',
  subtitle: 'Map result',
  city: 'Riga',
  category: 'activity',
  startsAtUtc: DateTime.utc(2026, 8, 3, 12),
  latitude: 56.94 + index / 100,
  longitude: 24.10 + index / 100,
  priceAmount: 0,
  distanceKm: index.toDouble(),
  isFree: true,
);

class _PreferencesRepository implements DiscoverPreferencesRepository {
  @override
  Future<void> deleteSavedSearch(String id) async {}

  @override
  Future<void> deleteSmartSearchPrompt(String id) async {}

  @override
  Future<DiscoverQuery?> loadLastQuery() async => null;

  @override
  Future<List<SavedSearchEntity>> loadSavedSearches() async =>
      const <SavedSearchEntity>[];

  @override
  Future<List<SmartSearchHistoryEntity>> loadSmartSearchHistory() async =>
      const <SmartSearchHistoryEntity>[];

  @override
  Future<void> saveLastQuery(DiscoverQuery query) async {}

  @override
  Future<void> saveSavedSearch(SavedSearchEntity search) async {}

  @override
  Future<void> saveSmartSearchPrompt(SmartSearchHistoryEntity item) async {}
}

class _FavoritesRepository implements FavoritesRepository {
  final items = <FavoriteItemEntity>[];

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async => items.add(item);

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async => items;

  @override
  Future<void> removeFavorite(String id) async =>
      items.removeWhere((item) => item.id == id);
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
