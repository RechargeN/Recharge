import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../core/telemetry/analytics_service.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/restore_session_usecase.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/create/data/datasources/create_local_datasource.dart';
import '../../features/create/data/repositories/create_repository_impl.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/usecases/load_create_draft_usecase.dart';
import '../../features/create/domain/usecases/publish_create_draft_usecase.dart';
import '../../features/create/domain/usecases/save_create_draft_usecase.dart';
import '../../features/discover/data/datasources/discover_remote_datasource.dart';
import '../../features/discover/data/datasources/discover_preferences_local_datasource.dart';
import '../../features/discover/data/repositories/discover_preferences_repository_impl.dart';
import '../../features/discover/data/repositories/discover_repository_impl.dart';
import '../../features/discover/domain/repositories/discover_preferences_repository.dart';
import '../../features/discover/domain/repositories/discover_repository.dart';
import '../../features/discover/domain/usecases/get_discover_details_usecase.dart';
import '../../features/discover/domain/usecases/get_discover_feed_usecase.dart';
import '../../features/explore/data/datasources/explore_local_datasource.dart';
import '../../features/explore/data/repositories/explore_repository_impl.dart';
import '../../features/explore/domain/repositories/explore_repository.dart';
import '../../features/explore/domain/usecases/load_profile_editable_usecase.dart';
import '../../features/explore/domain/usecases/load_settings_usecase.dart';
import '../../features/explore/domain/usecases/save_profile_editable_usecase.dart';
import '../../features/explore/domain/usecases/save_settings_usecase.dart';
import '../../features/favorites/data/datasources/favorites_local_datasource.dart';
import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../features/favorites/domain/usecases/add_favorite_usecase.dart';
import '../../features/favorites/domain/usecases/get_favorites_usecase.dart';
import '../../features/favorites/domain/usecases/remove_favorite_usecase.dart';
import '../../features/notifications/data/datasources/notifications_local_datasource.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/domain/usecases/get_notifications_usecase.dart';
import '../../features/notifications/domain/usecases/mark_notification_read_usecase.dart';

final GetIt sl = GetIt.instance;

Future<void> setupDependencies() async {
  if (sl.isRegistered<AnalyticsService>()) {
    return;
  }

  sl
    ..registerLazySingleton<AnalyticsService>(ConsoleAnalyticsService.new)
    ..registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new)
    ..registerLazySingleton<AuthRemoteDataSource>(MockAuthRemoteDataSource.new)
    ..registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSource(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
      ),
    )
    ..registerLazySingleton<DiscoverRemoteDataSource>(
      MockDiscoverRemoteDataSource.new,
    )
    ..registerLazySingleton<CreateLocalDataSource>(
      () => CreateLocalDataSource(sl()),
    )
    ..registerLazySingleton<CreateRepository>(
      () => CreateRepositoryImpl(localDataSource: sl()),
    )
    ..registerLazySingleton<DiscoverPreferencesLocalDataSource>(
      () => DiscoverPreferencesLocalDataSource(sl()),
    )
    ..registerLazySingleton<DiscoverRepository>(
      () => DiscoverRepositoryImpl(
        remoteDataSource: sl(),
      ),
    )
    ..registerLazySingleton<DiscoverPreferencesRepository>(
      () => DiscoverPreferencesRepositoryImpl(
        localDataSource: sl(),
      ),
    )
    ..registerLazySingleton<ExploreLocalDataSource>(
      () => ExploreLocalDataSource(sl()),
    )
    ..registerLazySingleton<ExploreRepository>(
      () => ExploreRepositoryImpl(localDataSource: sl()),
    )
    ..registerLazySingleton<FavoritesLocalDataSource>(
      () => FavoritesLocalDataSource(sl()),
    )
    ..registerLazySingleton<FavoritesRepository>(
      () => FavoritesRepositoryImpl(localDataSource: sl()),
    )
    ..registerLazySingleton<NotificationsLocalDataSource>(
      () => NotificationsLocalDataSource(sl()),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(localDataSource: sl()),
    )
    ..registerFactory<SignInUseCase>(() => SignInUseCase(sl()))
    ..registerFactory<RestoreSessionUseCase>(() => RestoreSessionUseCase(sl()))
    ..registerFactory<SignOutUseCase>(() => SignOutUseCase(sl()))
    ..registerFactory<GetCurrentUserUseCase>(() => GetCurrentUserUseCase(sl()))
    ..registerFactory<LoadCreateDraftUseCase>(
      () => LoadCreateDraftUseCase(sl()),
    )
    ..registerFactory<SaveCreateDraftUseCase>(
      () => SaveCreateDraftUseCase(sl()),
    )
    ..registerFactory<PublishCreateDraftUseCase>(
      () => PublishCreateDraftUseCase(sl()),
    )
    ..registerFactory<GetDiscoverFeedUseCase>(() => GetDiscoverFeedUseCase(sl()))
    ..registerFactory<GetDiscoverDetailsUseCase>(
      () => GetDiscoverDetailsUseCase(sl()),
    )
    ..registerFactory<LoadProfileEditableUseCase>(
      () => LoadProfileEditableUseCase(sl()),
    )
    ..registerFactory<SaveProfileEditableUseCase>(
      () => SaveProfileEditableUseCase(sl()),
    )
    ..registerFactory<LoadSettingsUseCase>(() => LoadSettingsUseCase(sl()))
    ..registerFactory<SaveSettingsUseCase>(() => SaveSettingsUseCase(sl()))
    ..registerFactory<GetFavoritesUseCase>(() => GetFavoritesUseCase(sl()))
    ..registerFactory<AddFavoriteUseCase>(() => AddFavoriteUseCase(sl()))
    ..registerFactory<RemoveFavoriteUseCase>(() => RemoveFavoriteUseCase(sl()))
    ..registerFactory<GetNotificationsUseCase>(
      () => GetNotificationsUseCase(sl()),
    )
    ..registerFactory<MarkNotificationReadUseCase>(
      () => MarkNotificationReadUseCase(sl()),
    );
}
