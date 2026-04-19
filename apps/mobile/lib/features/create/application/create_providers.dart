import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/usecases/load_create_draft_usecase.dart';
import '../domain/usecases/publish_create_draft_usecase.dart';
import '../domain/usecases/save_create_draft_usecase.dart';
import 'controllers/create_controller.dart';

final createControllerProvider = ChangeNotifierProvider<CreateController>((ref) {
  return CreateController(
    loadCreateDraftUseCase: sl<LoadCreateDraftUseCase>(),
    saveCreateDraftUseCase: sl<SaveCreateDraftUseCase>(),
    publishCreateDraftUseCase: sl<PublishCreateDraftUseCase>(),
    analyticsService: sl<AnalyticsService>(),
  );
});
