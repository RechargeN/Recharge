import '../domain/repositories/sign_out_everywhere.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/auth_session_events.dart';
import '../domain/repositories/network_status.dart';
import '../domain/repositories/offline_account_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/product_analytics/product_analytics_recorder.dart';
import 'controllers/auth_controller.dart';
import '../domain/usecases/get_current_user_usecase.dart';
import '../domain/usecases/restore_session_usecase.dart';
import '../domain/usecases/sign_in_usecase.dart';
import '../domain/usecases/sign_in_with_google_usecase.dart';
import '../domain/usecases/sign_out_usecase.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(
    sessionEvents: sl.isRegistered<AuthSessionEvents>()
        ? sl<AuthSessionEvents>()
        : null,
    signInUseCase: sl<SignInUseCase>(),
    signInWithGoogleUseCase: sl.isRegistered<SignInWithGoogleUseCase>()
        ? sl<SignInWithGoogleUseCase>()
        : null,
    restoreSessionUseCase: sl<RestoreSessionUseCase>(),
    signOutUseCase: sl<SignOutUseCase>(),
    // Owner 2026-11-23: only a server Session can be ended everywhere.
    signOutEverywhere: switch (sl<AuthRepository>()) {
      final SignOutEverywhere everywhere => everywhere,
      _ => null,
    },
    getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
    analyticsService: sl(),
    productAnalytics: sl.isRegistered<ProductAnalyticsRecorder>()
        ? sl<ProductAnalyticsRecorder>()
        : null,
    networkStatus: sl.isRegistered<NetworkStatus>()
        ? sl<NetworkStatus>()
        : null,
    offlineAccount: sl.isRegistered<OfflineAccountStore>()
        ? sl<OfflineAccountStore>()
        : null,
  );
});
