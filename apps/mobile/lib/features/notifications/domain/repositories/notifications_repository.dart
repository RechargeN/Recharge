import '../entities/notification_item_entity.dart';

abstract class NotificationsRepository {
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  });

  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  });
}
