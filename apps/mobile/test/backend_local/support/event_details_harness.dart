import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';

/// Page scaffolding only (app Auth and Favorites state for the Event Details
/// page). Booking authority never touches these: Booking uses its own Session.
final class SpyAnalytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

Future<AuthController> signedInAuthController() async {
  final AuthController controller = AuthController(
    signInUseCase: SignInUseCase(_AuthRepository()),
    restoreSessionUseCase: RestoreSessionUseCase(_AuthRepository()),
    signOutUseCase: SignOutUseCase(_AuthRepository()),
    getCurrentUserUseCase: GetCurrentUserUseCase(_AuthRepository()),
    analyticsService: SpyAnalytics(),
  );
  await controller.signIn(
    email: 'user@example.com',
    password: 'password123',
    sourceScreen: 'test',
    sourceAction: 'seed',
  );
  return controller;
}

FavoritesController favoritesFor() {
  final _FavoritesRepository repository = _FavoritesRepository();
  return FavoritesController(
    getFavoritesUseCase: GetFavoritesUseCase(repository),
    addFavoriteUseCase: AddFavoriteUseCase(repository),
    removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
    analyticsService: SpyAnalytics(),
  );
}

final class _AuthRepository implements AuthRepository {
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

final class _FavoritesRepository implements FavoritesRepository {
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
