import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import 'controllers/auth_controller.dart';
import '../domain/usecases/get_current_user_usecase.dart';
import '../domain/usecases/restore_session_usecase.dart';
import '../domain/usecases/sign_in_usecase.dart';
import '../domain/usecases/sign_out_usecase.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(
    signInUseCase: sl<SignInUseCase>(),
    restoreSessionUseCase: sl<RestoreSessionUseCase>(),
    signOutUseCase: sl<SignOutUseCase>(),
    getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
    analyticsService: sl(),
  );
});
