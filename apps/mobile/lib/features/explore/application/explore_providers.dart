import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/usecases/load_profile_editable_usecase.dart';
import '../domain/usecases/load_settings_usecase.dart';
import '../domain/usecases/save_profile_editable_usecase.dart';
import '../domain/usecases/save_settings_usecase.dart';
import 'controllers/explore_controller.dart';

final exploreControllerProvider = ChangeNotifierProvider<ExploreController>((ref) {
  return ExploreController(
    loadProfileEditableUseCase: sl<LoadProfileEditableUseCase>(),
    saveProfileEditableUseCase: sl<SaveProfileEditableUseCase>(),
    loadSettingsUseCase: sl<LoadSettingsUseCase>(),
    saveSettingsUseCase: sl<SaveSettingsUseCase>(),
    analyticsService: sl<AnalyticsService>(),
  );
});
