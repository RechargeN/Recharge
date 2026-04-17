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
import '../../features/discover/data/datasources/discover_remote_datasource.dart';
import '../../features/discover/data/datasources/discover_preferences_local_datasource.dart';
import '../../features/discover/data/repositories/discover_preferences_repository_impl.dart';
import '../../features/discover/data/repositories/discover_repository_impl.dart';
import '../../features/discover/domain/repositories/discover_preferences_repository.dart';
import '../../features/discover/domain/repositories/discover_repository.dart';
import '../../features/discover/domain/usecases/get_discover_details_usecase.dart';
import '../../features/discover/domain/usecases/get_discover_feed_usecase.dart';

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
    ..registerFactory<SignInUseCase>(() => SignInUseCase(sl()))
    ..registerFactory<RestoreSessionUseCase>(() => RestoreSessionUseCase(sl()))
    ..registerFactory<SignOutUseCase>(() => SignOutUseCase(sl()))
    ..registerFactory<GetCurrentUserUseCase>(() => GetCurrentUserUseCase(sl()))
    ..registerFactory<GetDiscoverFeedUseCase>(() => GetDiscoverFeedUseCase(sl()))
    ..registerFactory<GetDiscoverDetailsUseCase>(
      () => GetDiscoverDetailsUseCase(sl()),
    );
}
