import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/market_config.dart';
import '../../../app/di/service_locator.dart';
import '../../../core/notifications/app_notification_sink.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/usecases/create_professional_page_usecase.dart';
import '../domain/usecases/load_identity_workspace_usecase.dart';
import '../domain/usecases/request_page_limit_increase_usecase.dart';
import '../domain/usecases/select_workspace_usecase.dart';
import 'controllers/identity_workspace_controller.dart';
import 'controllers/public_professional_page_controller.dart';

final identityWorkspaceControllerProvider =
    ChangeNotifierProvider<IdentityWorkspaceController>((ref) {
      return IdentityWorkspaceController(
        loadIdentityWorkspaceUseCase: sl<LoadIdentityWorkspaceUseCase>(),
        selectWorkspaceUseCase: sl<SelectWorkspaceUseCase>(),
        createProfessionalPageUseCase: sl<CreateProfessionalPageUseCase>(),
        requestPageLimitIncreaseUseCase: sl<RequestPageLimitIncreaseUseCase>(),
        notificationSink: sl<AppNotificationSink>(),
        marketConfig: sl<MarketConfig>(),
        analyticsService: sl<AnalyticsService>(),
      );
    });

final publicProfessionalPageControllerProvider =
    ChangeNotifierProvider.autoDispose<PublicProfessionalPageController>((ref) {
      return PublicProfessionalPageController(
        resolvePage: sl(),
        loadIdentityWorkspace: sl(),
      );
    });
