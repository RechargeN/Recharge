import '../../../../core/notifications/app_notification_sink.dart';
import '../../domain/entities/notification_item_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_local_datasource.dart';
import '../models/notification_item_model.dart';

class NotificationsRepositoryImpl
    implements NotificationsRepository, AppNotificationSink {
  NotificationsRepositoryImpl({
    required NotificationsLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final NotificationsLocalDataSource _localDataSource;

  static const String moderatorInboxUserId = '__moderators__';

  @override
  Future<void> appendNotification(AppNotificationEvent event) async {
    final String recipientKey = switch (event.audience) {
      AppNotificationAudience.user => event.recipientUserId?.trim() ?? '',
      AppNotificationAudience.moderators => moderatorInboxUserId,
    };
    if (recipientKey.isEmpty) {
      throw ArgumentError.value(
        event.recipientUserId,
        'recipientUserId',
        'User notification requires a recipient',
      );
    }

    final List<NotificationItemModel> stored = await _localDataSource
        .readNotifications(recipientKey);
    if (stored.any((NotificationItemModel item) => item.id == event.id)) {
      return;
    }
    final NotificationItemModel item = NotificationItemModel(
      id: event.id,
      title: event.title,
      body: event.body,
      type: NotificationType.system.name,
      createdAtUtcIso: event.createdAtUtc.toUtc().toIso8601String(),
      isRead: false,
      targetRoute: event.targetRoute,
    );
    await _localDataSource.writeNotifications(
      recipientKey,
      <NotificationItemModel>[item, ...stored],
    );
  }

  @override
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  }) async {
    final List<NotificationItemModel> stored = await _localDataSource
        .readNotifications(userId);
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
    final List<NotificationItemModel> stored = await _localDataSource
        .readNotifications(userId);
    final List<NotificationItemModel> updated = stored
        .map((NotificationItemModel item) {
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
            subjectKind: item.subjectKind,
            subjectId: item.subjectId,
            scenarioDraftId: item.scenarioDraftId,
            scenarioItemId: item.scenarioItemId,
          );
        })
        .toList(growable: false);
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
        createdAtUtcIso: now
            .subtract(const Duration(minutes: 35))
            .toIso8601String(),
        isRead: false,
        targetRoute: '/discover',
      ),
      NotificationItemModel(
        id: 'notif_scenario_occurrence_morning',
        title: 'Изменились часы места в вашем Scenario',
        body: 'Утренняя остановка GORS требует проверки времени.',
        type: NotificationType.activity.name,
        createdAtUtcIso: now
            .subtract(const Duration(minutes: 55))
            .toIso8601String(),
        isRead: false,
        targetRoute: '/discover/details/place-1',
        subjectKind: NotificationSubjectKind.place.name,
        subjectId: 'place-1',
        scenarioDraftId: 'scenario-demo-1',
        scenarioItemId: 'scenario-item-morning',
      ),
      NotificationItemModel(
        id: 'notif_scenario_occurrence_evening',
        title: 'Изменились часы места в вашем Scenario',
        body: 'Вечерняя остановка GORS требует проверки времени.',
        type: NotificationType.activity.name,
        createdAtUtcIso: now
            .subtract(const Duration(minutes: 56))
            .toIso8601String(),
        isRead: false,
        targetRoute: '/discover/details/place-1',
        subjectKind: NotificationSubjectKind.place.name,
        subjectId: 'place-1',
        scenarioDraftId: 'scenario-demo-1',
        scenarioItemId: 'scenario-item-evening',
      ),
      NotificationItemModel(
        id: 'notif_2',
        title: 'Напоминание о событии',
        body: 'Через 2 часа начинается ваше сохраненное событие.',
        type: NotificationType.reminder.name,
        createdAtUtcIso: now
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        isRead: false,
        targetRoute: '/favorites',
      ),
      NotificationItemModel(
        id: 'notif_creator_publish',
        title: 'Листинг отправлен на модерацию',
        body: 'Мы покажем статус проверки в вашем creator workspace.',
        type: NotificationType.activity.name,
        createdAtUtcIso: now
            .subtract(const Duration(hours: 4))
            .toIso8601String(),
        isRead: true,
        targetRoute: '/profile',
      ),
      NotificationItemModel(
        id: 'notif_3',
        title: 'Системное обновление',
        body: 'Мы улучшили поиск и производительность приложения.',
        type: NotificationType.system.name,
        createdAtUtcIso: now
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        isRead: true,
        targetRoute: null,
      ),
    ];
  }
}
