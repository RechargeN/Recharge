import 'package:api_contracts/api_contracts.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/notification_item_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import 'notifications_inbox_port.dart';

/// F1: the server inbox behind the default-off test entry. The server is the
/// only authority for records and read state; this repository keeps no copy.
/// The caller is the Session subject, so `userId` is never sent.
final class ServerNotificationsRepository implements NotificationsRepository {
  ServerNotificationsRepository({
    required NotificationsInboxPort port,
    this.locale = 'ru',
    String Function()? newRequestId,
  }) : _port = port,
       _newRequestId = newRequestId ?? const Uuid().v4;

  final NotificationsInboxPort _port;
  final String Function() _newRequestId;

  /// One of the LV product locales (`lv-LV`, `en`, `ru`); the app UI is Russian.
  final String locale;

  static const int _pageSize = 50;

  @override
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  }) async {
    final Map<String, Object?> answer = await _port.query(<String, Object?>{
      'schemaVersion': 1,
      'requestId': _newRequestId(),
      'queryType': 'listInbox',
      'payload': <String, Object?>{'locale': locale, 'pageSize': _pageSize},
    });
    _refuseUnlessSucceeded(answer);
    final NotificationInboxPageDto page;
    try {
      page = NotificationInboxPageDto.fromJson(answer);
    } on FormatException {
      throw const NotificationsInboxFailure('answer_invalid');
    }
    return page.items.map(_entity).toList(growable: false);
  }

  @override
  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) async {
    final Map<String, Object?> answer = await _port.command(<String, Object?>{
      'schemaVersion': 1,
      'requestId': _newRequestId(),
      // Same key for every retry of the same logical read.
      'idempotencyKey': 'read-$notificationId',
      'commandType': 'markRead',
      'payload': <String, Object?>{'notificationId': notificationId},
    });
    _refuseUnlessSucceeded(answer);
  }

  static void _refuseUnlessSucceeded(Map<String, Object?> answer) {
    if (answer['kind'] == 'succeeded') return;
    final Object? code = answer['code'];
    throw NotificationsInboxFailure(code is String ? code : 'answer_invalid');
  }

  static NotificationItemEntity _entity(NotificationInboxItemDto item) {
    return NotificationItemEntity(
      id: item.notificationId,
      // A missing locale is shown as such; there is no fallback text.
      title: item.title ?? 'Уведомление',
      body: item.body ?? 'Текст недоступен на этом языке.',
      type: item.category == NotificationInboxCategory.bookingChanges
          ? NotificationType.reminder
          : NotificationType.activity,
      createdAtUtc: item.createdAtUtc,
      isRead: item.status != NotificationInboxStatus.unread,
      targetRoute: null,
      subjectRef: NotificationSubjectRef(
        kind: NotificationSubjectKind.event,
        id: item.navigation.eventId,
      ),
    );
  }
}
