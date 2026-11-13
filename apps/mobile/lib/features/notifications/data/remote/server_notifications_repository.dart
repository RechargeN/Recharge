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
    String Function()? wireLocale,
    String Function()? newRequestId,
  }) : _port = port,
       _wireLocale = wireLocale ?? _fallbackWireLocale,
       _newRequestId = newRequestId ?? const Uuid().v4;

  final NotificationsInboxPort _port;
  final String Function() _newRequestId;

  /// L4: the reader's current UI language as a notifications wire locale
  /// (`lv-LV`, `en` or `ru`), read at query time. The recipient's own
  /// language decides the text; the initiator's language is never stored.
  final String Function() _wireLocale;

  static String _fallbackWireLocale() => 'en';

  static const int _pageSize = 50;

  @override
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  }) async {
    final Map<String, Object?> answer = await _port.query(<String, Object?>{
      'schemaVersion': 1,
      'requestId': _newRequestId(),
      'queryType': 'listInbox',
      'payload': <String, Object?>{
        'locale': _wireLocale(),
        'pageSize': _pageSize,
      },
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
      // A missing locale is shown as such by the UI; there is no fallback
      // text in another language and no text is made up here.
      title: item.title ?? '',
      body: item.body ?? '',
      contentAvailability: switch (item.contentStatus) {
        NotificationContentStatus.rendered =>
          NotificationContentAvailability.rendered,
        NotificationContentStatus.unsupportedLocale =>
          NotificationContentAvailability.unsupportedLocale,
        NotificationContentStatus.templateUnavailable =>
          NotificationContentAvailability.templateUnavailable,
      },
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
