import 'dart:convert';
import 'dart:io';

import 'package:api_contracts/api_contracts.dart';
import 'package:test/test.dart';

const String _notificationsRoot = 'schema/notifications/v1';

List<Map<String, Object?>> _results() {
  final Object? raw = jsonDecode(
    File('$_notificationsRoot/fixtures/result_valid.json').readAsStringSync(),
  );
  return (raw! as List<Object?>)
      .map((Object? value) => (value! as Map).cast<String, Object?>())
      .toList(growable: false);
}

Map<String, Object?> _page() => _results().firstWhere(
  (Map<String, Object?> result) =>
      result['queryType'] == 'listInbox' && result['kind'] == 'succeeded',
);

Map<String, Object?> _copy(Map<String, Object?> value) =>
    (jsonDecode(jsonEncode(value))! as Map).cast<String, Object?>();

void main() {
  test('the listInbox fixture parses into a typed page', () {
    final NotificationInboxPageDto page = NotificationInboxPageDto.fromJson(
      _page(),
    );
    expect(page.locale, 'ru');
    expect(page.view, 'active');
    expect(page.nextCursor, isNull);
    final NotificationInboxItemDto item = page.items.single;
    expect(item.notificationId, 'ntf_0123456789abcdef0123456789abcdef');
    expect(item.category, NotificationInboxCategory.bookingReceipts);
    expect(item.status, NotificationInboxStatus.unread);
    expect(item.title, 'Бронь подтверждена');
    expect(item.contentStatus, NotificationContentStatus.rendered);
    expect(item.navigation.eventId, 'evt_01JF1FIXTUREEVENT00000000');
    expect(item.createdAtUtc, DateTime.utc(2026, 8, 29, 12, 0, 1));
    expect(item.readAtUtc, isNull);
  });

  test('unknown fields, URLs and inconsistent content fail closed', () {
    Map<String, Object?> itemOf(Map<String, Object?> page) =>
        ((page['items']! as List<Object?>).single! as Map)
            .cast<String, Object?>();

    final Map<String, Object?> extra = _copy(_page());
    itemOf(extra)['recipientId'] = 'someone';
    expect(
      () => NotificationInboxPageDto.fromJson(extra),
      throwsA(isA<BookingContractFormatException>()),
    );

    final Map<String, Object?> url = _copy(_page());
    itemOf(url)['navigation'] = <String, Object?>{
      'routeKind': 'url',
      'objectRef': <String, Object?>{'type': 'event', 'id': 'x'},
      'routeContractVersion': 1,
    };
    expect(
      () => NotificationInboxPageDto.fromJson(url),
      throwsA(isA<BookingContractFormatException>()),
    );

    final Map<String, Object?> missingText = _copy(_page());
    itemOf(missingText)['content'] = null;
    expect(
      () => NotificationInboxPageDto.fromJson(missingText),
      throwsA(isA<BookingContractFormatException>()),
    );

    final Map<String, Object?> unsupported = _copy(_page());
    itemOf(unsupported)
      ..['content'] = null
      ..['contentStatus'] = 'unsupported_locale';
    final NotificationInboxItemDto item = NotificationInboxPageDto.fromJson(
      unsupported,
    ).items.single;
    expect(item.title, isNull);
    expect(item.contentStatus, NotificationContentStatus.unsupportedLocale);

    final Map<String, Object?> refusal = _results().firstWhere(
      (Map<String, Object?> result) => result['kind'] == 'rejected',
    );
    expect(
      () => NotificationInboxPageDto.fromJson(refusal),
      throwsA(isA<BookingContractFormatException>()),
    );
  });
}
