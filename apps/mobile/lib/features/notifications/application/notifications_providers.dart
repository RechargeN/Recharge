import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/usecases/get_notifications_usecase.dart';
import '../domain/usecases/mark_notification_read_usecase.dart';
import 'controllers/notifications_controller.dart';

final notificationsControllerProvider =
    ChangeNotifierProvider<NotificationsController>((ref) {
  return NotificationsController(
    getNotificationsUseCase: sl<GetNotificationsUseCase>(),
    markNotificationReadUseCase: sl<MarkNotificationReadUseCase>(),
    analyticsService: sl<AnalyticsService>(),
  );
});
