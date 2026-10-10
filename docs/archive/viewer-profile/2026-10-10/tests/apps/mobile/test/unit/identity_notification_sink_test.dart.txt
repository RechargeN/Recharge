import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/notifications/app_notification_sink.dart';
import 'package:recharge/features/notifications/data/datasources/notifications_local_datasource.dart';
import 'package:recharge/features/notifications/data/repositories/notifications_repository_impl.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('page notification is durable and idempotent for user', () async {
    final repository = NotificationsRepositoryImpl(
      localDataSource: NotificationsLocalDataSource(
        const FlutterSecureStorage(),
      ),
    );
    final event = AppNotificationEvent(
      id: 'page-event-user',
      audience: AppNotificationAudience.user,
      recipientUserId: 'user-id',
      title: 'Page created',
      body: 'Pending review',
      createdAtUtc: DateTime.utc(2026, 7, 31),
    );

    await repository.appendNotification(event);
    await repository.appendNotification(event);

    final items = await repository.getNotifications(userId: 'user-id');
    expect(items, hasLength(1));
    expect(items.single.id, event.id);
  });

  test('moderator event is written to separate moderator inbox', () async {
    final repository = NotificationsRepositoryImpl(
      localDataSource: NotificationsLocalDataSource(
        const FlutterSecureStorage(),
      ),
    );

    await repository.appendNotification(
      AppNotificationEvent(
        id: 'page-event-moderators',
        audience: AppNotificationAudience.moderators,
        title: 'New page',
        body: 'Review required',
        createdAtUtc: DateTime.utc(2026, 7, 31),
      ),
    );

    final items = await repository.getNotifications(
      userId: NotificationsRepositoryImpl.moderatorInboxUserId,
    );
    expect(items.single.id, 'page-event-moderators');
  });
}
