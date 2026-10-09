import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/notifications/data/remote/notifications_inbox_port.dart';
import 'package:recharge/features/notifications/data/remote/server_notifications_repository.dart';
import 'package:recharge/features/notifications/domain/entities/notification_item_entity.dart';

final class _FakePort implements NotificationsInboxPort {
  final List<Map<String, Object?>> queries = <Map<String, Object?>>[];
  final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
  Map<String, Object?> queryAnswer = <String, Object?>{};
  Map<String, Object?> commandAnswer = <String, Object?>{
    'schemaVersion': 1,
    'commandType': 'markRead',
    'requestId': 'r',
    'kind': 'succeeded',
  };

  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) async {
    queries.add(request);
    return queryAnswer;
  }

  @override
  Future<Map<String, Object?>> command(Map<String, Object?> request) async {
    commands.add(request);
    return commandAnswer;
  }
}

Map<String, Object?> _item({
  required String id,
  required String category,
  required String status,
  Map<String, Object?>? content,
  String contentStatus = 'rendered',
}) => <String, Object?>{
  'notificationId': id,
  'category': category,
  'status': status,
  'revision': 1,
  'createdAtUtc': '2026-08-29T12:00:01.000Z',
  'occurredAtUtc': '2026-08-29T12:00:00.000Z',
  'readAtUtc': status == 'unread' ? null : '2026-08-29T13:00:00.000Z',
  'archivedAtUtc': null,
  'template': <String, Object?>{'key': 'booking.confirmed', 'revision': 1},
  'content': content,
  'contentStatus': contentStatus,
  'navigation': <String, Object?>{
    'routeKind': 'eventDetails',
    'objectRef': <String, Object?>{'type': 'event', 'id': 'evt-1'},
    'routeContractVersion': 1,
  },
};

Map<String, Object?> _page(List<Map<String, Object?>> items) =>
    <String, Object?>{
      'schemaVersion': 1,
      'queryType': 'listInbox',
      'requestId': 'r',
      'kind': 'succeeded',
      'locale': 'ru',
      'view': 'active',
      'items': items,
      'nextCursor': null,
    };

void main() {
  test('lists the server inbox without sending a user id', () async {
    final _FakePort port = _FakePort()
      ..queryAnswer = _page(<Map<String, Object?>>[
        _item(
          id: 'ntf_0123456789abcdef0123456789abcdef',
          category: 'booking.changes',
          status: 'unread',
          content: <String, Object?>{'title': 'Событие отменено', 'body': 'B'},
        ),
        _item(
          id: 'ntf_fedcba9876543210fedcba9876543210',
          category: 'booking.receipts',
          status: 'read',
          content: null,
          contentStatus: 'unsupported_locale',
        ),
      ]);
    final repository = ServerNotificationsRepository(
      port: port,
      newRequestId: () => 'req-fixed',
    );
    final List<NotificationItemEntity> items = await repository
        .getNotifications(userId: 'local-user');
    expect(port.queries.single, <String, Object?>{
      'schemaVersion': 1,
      'requestId': 'req-fixed',
      'queryType': 'listInbox',
      'payload': <String, Object?>{'locale': 'ru', 'pageSize': 50},
    });
    expect(items, hasLength(2));
    expect(items.first.title, 'Событие отменено');
    expect(items.first.type, NotificationType.reminder);
    expect(items.first.isRead, isFalse);
    expect(items.first.subjectRef?.kind, NotificationSubjectKind.event);
    expect(items.first.subjectRef?.id, 'evt-1');
    expect(items.first.targetRoute, isNull);
    expect(items.last.type, NotificationType.activity);
    expect(items.last.isRead, isTrue);
    expect(items.last.body, 'Текст недоступен на этом языке.');
  });

  test(
    'markRead uses one idempotency key per record for every retry',
    () async {
      final _FakePort port = _FakePort();
      final repository = ServerNotificationsRepository(port: port);
      await repository.markNotificationRead(
        userId: 'ignored',
        notificationId: 'ntf_0123456789abcdef0123456789abcdef',
      );
      await repository.markNotificationRead(
        userId: 'ignored',
        notificationId: 'ntf_0123456789abcdef0123456789abcdef',
      );
      expect(
        port.commands.map(
          (Map<String, Object?> command) => command['idempotencyKey'],
        ),
        everyElement('read-ntf_0123456789abcdef0123456789abcdef'),
      );
      expect(port.commands.first.containsKey('userId'), isFalse);
    },
  );

  test(
    'refusals and malformed answers fail typed, never as empty lists',
    () async {
      final _FakePort port = _FakePort()
        ..queryAnswer = <String, Object?>{
          'schemaVersion': 1,
          'kind': 'rejected',
          'code': 'feature_disabled',
        };
      final repository = ServerNotificationsRepository(port: port);
      await expectLater(
        repository.getNotifications(userId: 'u'),
        throwsA(
          isA<NotificationsInboxFailure>().having(
            (NotificationsInboxFailure failure) => failure.code,
            'code',
            'feature_disabled',
          ),
        ),
      );
      port.queryAnswer = _page(<Map<String, Object?>>[
        <String, Object?>{
          ..._item(id: 'bad', category: 'booking.receipts', status: 'unread'),
        },
      ]);
      await expectLater(
        repository.getNotifications(userId: 'u'),
        throwsA(
          isA<NotificationsInboxFailure>().having(
            (NotificationsInboxFailure failure) => failure.code,
            'code',
            'answer_invalid',
          ),
        ),
      );
      port.commandAnswer = <String, Object?>{
        'schemaVersion': 1,
        'kind': 'rejected',
        'code': 'notification_not_found',
      };
      await expectLater(
        repository.markNotificationRead(userId: 'u', notificationId: 'ntf_x'),
        throwsA(isA<NotificationsInboxFailure>()),
      );
    },
  );
}
