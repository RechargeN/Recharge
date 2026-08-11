import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/notifications/application/controllers/notifications_controller.dart';
import 'package:recharge/features/notifications/application/state/notifications_state.dart';
import 'package:recharge/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:recharge/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:recharge/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:recharge/features/notifications/domain/usecases/mark_notification_read_usecase.dart';

void main() {
  late _FakeNotificationsRepository repository;
  late NotificationsController controller;

  setUp(() {
    repository = _FakeNotificationsRepository();
    controller = NotificationsController(
      getNotificationsUseCase: GetNotificationsUseCase(repository),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );
  });

  test('load notifications -> ready with unread count', () async {
    await controller.ensureLoaded(userId: 'u1');

    expect(controller.state.status, NotificationsStatus.ready);
    expect(controller.state.items, hasLength(3));
    expect(controller.state.unreadCount, 1);
  });

  test('searches title, body, type, time, and tolerates typos', () async {
    await controller.ensureLoaded(userId: 'u1');

    controller.updateSearchQuery('бронированеи');
    expect(controller.state.searchResults.single.id, 'n3');

    controller.updateSearchQuery('15:00');
    expect(controller.state.searchResults.single.id, 'n3');

    controller.updateSearchQuery('бронирование подтверждено');
    expect(controller.state.searchResults.single.id, 'n3');

    controller.updateSearchQuery('напоминание');
    expect(controller.state.searchResults.single.id, 'n1');

    controller.updateSearchQuery('несуществующее');
    expect(controller.state.searchResults, isEmpty);

    controller.clearSearch();
    expect(controller.state.searchResults, hasLength(3));
    expect(controller.state.searchQuery, isEmpty);
  });

  test('markAsRead updates unread count', () async {
    await controller.ensureLoaded(userId: 'u1');

    await controller.markAsRead('n1');

    expect(controller.state.unreadCount, 0);
    expect(
      controller.state.items
          .firstWhere((NotificationItemEntity item) => item.id == 'n1')
          .isRead,
      isTrue,
    );
  });

  test('markAllAsRead clears all unread notifications', () async {
    await controller.ensureLoaded(userId: 'u1');

    await controller.markAllAsRead();

    expect(controller.state.unreadCount, 0);
    expect(
      controller.state.items.every(
        (NotificationItemEntity item) => item.isRead,
      ),
      isTrue,
    );
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeNotificationsRepository implements NotificationsRepository {
  final List<NotificationItemEntity> _storage = <NotificationItemEntity>[
    NotificationItemEntity(
      id: 'n1',
      title: 'Reminder',
      body: 'Body',
      type: NotificationType.reminder,
      createdAtUtc: DateTime.parse('2026-04-20T10:00:00Z'),
      isRead: false,
      targetRoute: '/discover',
    ),
    NotificationItemEntity(
      id: 'n2',
      title: 'System',
      body: 'Body2',
      type: NotificationType.system,
      createdAtUtc: DateTime.parse('2026-04-20T09:00:00Z'),
      isRead: true,
      targetRoute: null,
    ),
    NotificationItemEntity(
      id: 'n3',
      title: 'Ваше бронирование подтверждено',
      body: 'Ждем в 15: 00.',
      type: NotificationType.activity,
      createdAtUtc: DateTime.parse('2026-04-20T08:00:00Z'),
      isRead: true,
      targetRoute: '/discover',
    ),
  ];

  @override
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  }) async {
    return List<NotificationItemEntity>.from(_storage);
  }

  @override
  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) async {
    final int index = _storage.indexWhere(
      (NotificationItemEntity item) => item.id == notificationId,
    );
    if (index < 0) return;
    _storage[index] = _storage[index].copyWith(isRead: true);
  }
}
