import '../domain/repositories/auth_session_events.dart';
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
    getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
    analyticsService: sl(),
    productAnalytics: sl.isRegistered<ProductAnalyticsRecorder>()
        ? sl<ProductAnalyticsRecorder>()
        : null,
  );
});
