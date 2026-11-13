import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/repositories/notification_channel_settings_repository.dart';
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

/// N3c: channel preferences and the owner's self-test; registered only in the
/// dev flavor with `N3C_DEV_PUSH=true`, otherwise null (no UI entry).
final notificationChannelSettingsProvider =
    Provider<NotificationChannelSettingsRepository?>(
      (ref) => sl.isRegistered<NotificationChannelSettingsRepository>()
          ? sl<NotificationChannelSettingsRepository>()
          : null,
    );
