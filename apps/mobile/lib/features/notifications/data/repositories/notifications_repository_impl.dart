import '../../domain/entities/notification_item_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_local_datasource.dart';
import '../models/notification_item_model.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({
    required NotificationsLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final NotificationsLocalDataSource _localDataSource;

  @override
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  }) async {
    final List<NotificationItemModel> stored =
        await _localDataSource.readNotifications(userId);
    if (stored.isEmpty) {
      final List<NotificationItemModel> seeded = _seedNotifications();
      await _localDataSource.writeNotifications(userId, seeded);
      return seeded
          .map((NotificationItemModel item) => item.toEntity())
          .toList(growable: false);
    }
    return stored
        .map((NotificationItemModel item) => item.toEntity())
        .toList(growable: false);
  }

  @override
  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) async {
    final List<NotificationItemModel> stored =
        await _localDataSource.readNotifications(userId);
    final List<NotificationItemModel> updated =
        stored.map((NotificationItemModel item) {
      if (item.id != notificationId || item.isRead) {
        return item;
      }
      return NotificationItemModel(
        id: item.id,
        title: item.title,
        body: item.body,
        type: item.type,
        createdAtUtcIso: item.createdAtUtcIso,
        isRead: true,
        targetRoute: item.targetRoute,
      );
    }).toList(growable: false);
    await _localDataSource.writeNotifications(userId, updated);
  }

  List<NotificationItemModel> _seedNotifications() {
    final DateTime now = DateTime.now().toUtc();
    return <NotificationItemModel>[
      NotificationItemModel(
        id: 'notif_1',
        title: 'Новые активности рядом',
        body: 'Мы нашли несколько событий рядом с вами на сегодня.',
        type: NotificationType.activity.name,
        createdAtUtcIso: now.subtract(const Duration(minutes: 35)).toIso8601String(),
        isRead: false,
        targetRoute: '/discover',
      ),
      NotificationItemModel(
        id: 'notif_route_1',
        title: 'Готов спокойный маршрут',
        body: 'Кофе, прогулка и тихая точка рядом с вами.',
        type: NotificationType.activity.name,
        createdAtUtcIso: now.subtract(const Duration(minutes: 55)).toIso8601String(),
        isRead: false,
        targetRoute:
            '/scenario-builder?mood=calm&duration=90&free=1&walking=1'
            '&prompt=quiet%20coffee%20walk%20nearby'
            '&steps=food_drinks.coffee,wellness_recharge.calm_walk,'
            'outdoor_nature_walking.city_walk',
      ),
      NotificationItemModel(
        id: 'notif_2',
        title: 'Напоминание о событии',
        body: 'Через 2 часа начинается ваше сохраненное событие.',
        type: NotificationType.reminder.name,
        createdAtUtcIso: now.subtract(const Duration(hours: 2)).toIso8601String(),
        isRead: false,
        targetRoute: '/favorites',
      ),
      NotificationItemModel(
        id: 'notif_creator_publish',
        title: 'Листинг отправлен на модерацию',
        body: 'Мы покажем статус проверки в вашем creator workspace.',
        type: NotificationType.activity.name,
        createdAtUtcIso: now.subtract(const Duration(hours: 4)).toIso8601String(),
        isRead: true,
        targetRoute: '/profile',
      ),
      NotificationItemModel(
        id: 'notif_3',
        title: 'Системное обновление',
        body: 'Мы улучшили поиск и производительность приложения.',
        type: NotificationType.system.name,
        createdAtUtcIso: now.subtract(const Duration(days: 1)).toIso8601String(),
        isRead: true,
        targetRoute: null,
      ),
    ];
  }
}
