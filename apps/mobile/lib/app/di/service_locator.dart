import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../config/market_config.dart';
import '../config/travel_policy_config.dart';
import '../../core/telemetry/analytics_service.dart';
import '../../core/id/id_generator.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/restore_session_usecase.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/create/data/datasources/create_local_datasource.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/data/repositories/create_repository_impl.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/usecases/load_create_draft_usecase.dart';
import '../../features/create/domain/usecases/publish_create_draft_usecase.dart';
import '../../features/create/domain/usecases/save_create_draft_usecase.dart';
import '../../features/discover/data/datasources/discover_remote_datasource.dart';
import '../../features/discover/data/datasources/discover_preferences_local_datasource.dart';
import '../../features/discover/data/repositories/discover_preferences_repository_impl.dart';
import '../../features/discover/data/repositories/discover_repository_impl.dart';
import '../../features/discover/data/repositories/timezone_repository_impl.dart';
import '../../features/discover/data/repositories/travel_time_repository_impl.dart';
import '../../features/discover/data/repositories/time_fit_evaluation_store_impl.dart';
import '../../features/discover/domain/entities/discover_query.dart';
import '../../features/discover/domain/repositories/discover_preferences_repository.dart';
import '../../features/discover/domain/repositories/discover_repository.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';
import '../../features/discover/domain/repositories/travel_time_repository.dart';
import '../../features/discover/domain/repositories/time_fit_evaluation_store.dart';
import '../../features/discover/domain/usecases/apply_time_window_usecase.dart';
import '../../features/discover/domain/usecases/build_time_window_usecase.dart';
import '../../features/discover/domain/usecases/calculate_time_fit_score_usecase.dart';
import '../../features/discover/domain/usecases/calculate_travel_times_usecase.dart';
import '../../features/discover/domain/usecases/get_discover_details_usecase.dart';
import '../../features/discover/domain/usecases/get_discover_feed_usecase.dart';
import '../../features/discover/application/discover_runtime_defaults.dart';
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
    ..registerLazySingleton<MarketRegistry>(MarketRegistry.new)
    ..registerLazySingleton<MarketConfig>(() => sl<MarketRegistry>().active)
    ..registerLazySingleton<TravelPolicyConfig>(TravelPolicyConfig.new)
    ..registerLazySingleton<IdGenerator>(UuidV4IdGenerator.new)
    ..registerLazySingleton<DiscoverQuery>(
      () => DiscoverQuery.defaults(
        marketCityId: sl<MarketConfig>().marketCityId,
        centerLat: sl<MarketConfig>().centerLat,
        centerLng: sl<MarketConfig>().centerLng,
      ),
    )
    ..registerLazySingleton<CreateRuntimeDefaults>(
      () => CreateRuntimeDefaults(
        marketCityId: sl<MarketConfig>().marketCityId,
        timezone: sl<MarketConfig>().timezoneId,
        country: sl<MarketConfig>().countryCode,
        city: sl<MarketConfig>().cityName,
        currency: sl<MarketConfig>().currencyCode,
      ),
    )
    ..registerLazySingleton<DiscoverRuntimeDefaults>(
      () => DiscoverRuntimeDefaults(
        timezoneId: sl<MarketConfig>().timezoneId,
        originLat: sl<MarketConfig>().centerLat,
        originLng: sl<MarketConfig>().centerLng,
      ),
    )
    ..registerLazySingleton<AnalyticsService>(ConsoleAnalyticsService.new)
    ..registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new)
    ..registerLazySingleton<AuthRemoteDataSource>(MockAuthRemoteDataSource.new)
    ..registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSource(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    )
    ..registerLazySingleton<DiscoverRemoteDataSource>(
      MockDiscoverRemoteDataSource.new,
    )
    ..registerLazySingleton<CreateLocalDataSource>(
      () => CreateLocalDataSource(
        sl(),
        activeMarketCityId: sl<CreateRuntimeDefaults>().marketCityId,
        activeTimezone: sl<CreateRuntimeDefaults>().timezone,
        activeCountry: sl<CreateRuntimeDefaults>().country,
        activeCity: sl<CreateRuntimeDefaults>().city,
      ),
    )
    ..registerLazySingleton<CreateRepository>(
      () => CreateRepositoryImpl(localDataSource: sl(), idGenerator: sl()),
    )
    ..registerLazySingleton<DiscoverPreferencesLocalDataSource>(
      () => DiscoverPreferencesLocalDataSource(
        sl(),
        defaultMarketCityId: sl<MarketConfig>().marketCityId,
        defaultCenterLat: sl<MarketConfig>().centerLat,
        defaultCenterLng: sl<MarketConfig>().centerLng,
      ),
    )
    ..registerLazySingleton<DiscoverRepository>(
      () => DiscoverRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<TimezoneRepository>(TimezoneRepositoryImpl.new)
    ..registerLazySingleton<TravelTimeRepository>(
      () => TravelTimeRepositoryImpl(
        walkingSpeedKmh: sl<TravelPolicyConfig>().walkingSpeedKmh,
        walkingRouteFactor: sl<TravelPolicyConfig>().walkingRouteFactor,
        drivingSpeedKmh: sl<TravelPolicyConfig>().drivingSpeedKmh,
        drivingRouteFactor: sl<TravelPolicyConfig>().drivingRouteFactor,
        transitSpeedKmh: sl<TravelPolicyConfig>().transitSpeedKmh,
        transitRouteFactor: sl<TravelPolicyConfig>().transitRouteFactor,
      ),
    )
    ..registerLazySingleton<TimeFitEvaluationStore>(
      InMemoryTimeFitEvaluationStore.new,
    )
    ..registerLazySingleton<DiscoverPreferencesRepository>(
      () => DiscoverPreferencesRepositoryImpl(localDataSource: sl()),
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
    ..registerFactory<CalculateTravelTimesUseCase>(
      () => CalculateTravelTimesUseCase(sl()),
    )
    ..registerFactory<BuildTimeWindowUseCase>(
      () => BuildTimeWindowUseCase(sl()),
    )
    ..registerFactory<CalculateTimeFitScoreUseCase>(
      () => CalculateTimeFitScoreUseCase(
        timeFitWeight: sl<TravelPolicyConfig>().effectiveTimeFitWeight,
      ),
    )
    ..registerFactory<ApplyTimeWindowUseCase>(
      () => ApplyTimeWindowUseCase(
        calculateTravelTimes: sl(),
        timezoneRepository: sl(),
        calculateTimeFitScore: sl(),
        placeReturnSafetyRatio: sl<TravelPolicyConfig>().placeReturnSafetyRatio,
        placeReturnSafetyMinMinutes:
            sl<TravelPolicyConfig>().placeReturnSafetyMinMinutes,
        placeReturnSafetyMaxMinutes:
            sl<TravelPolicyConfig>().placeReturnSafetyMaxMinutes,
        onInvalidOpeningRule: (String objectId) {
          sl<AnalyticsService>().track(
            'time_fit_invalid_opening_rule',
            params: <String, Object?>{'object_id': objectId},
          );
        },
      ),
    )
    ..registerFactory<GetDiscoverFeedUseCase>(
      () => GetDiscoverFeedUseCase(
        sl(),
        applyTimeWindow: sl(),
        evaluationStore: sl(),
      ),
    )
    ..registerFactory<GetDiscoverDetailsUseCase>(
      () => GetDiscoverDetailsUseCase(sl(), evaluationStore: sl()),
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
