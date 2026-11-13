import 'package:uuid/uuid.dart';

import '../../domain/repositories/notification_channel_settings_repository.dart';
import 'notifications_inbox_port.dart';

/// N3c: channel preferences over `notificationsQueryV1` (`getPreferences`) and
/// `notificationsCommandV1` (`updatePreferences`); the dev self-test goes
/// through its own callable. The caller is the Session subject.
final class ServerNotificationChannelSettingsRepository
    implements NotificationChannelSettingsRepository {
  ServerNotificationChannelSettingsRepository({
    required NotificationsInboxPort port,
    required Future<Map<String, Object?>> Function(Map<String, Object?>)
    selfTest,
    String Function()? newRequestId,
  }) : _port = port,
       _selfTest = selfTest,
       _newRequestId = newRequestId ?? const Uuid().v4;

  final NotificationsInboxPort _port;
  final Future<Map<String, Object?>> Function(Map<String, Object?>) _selfTest;
  final String Function() _newRequestId;

  @override
  Future<NotificationChannelSettings> load() async => _parse(
    await _port.query(<String, Object?>{
      'schemaVersion': 1,
      'requestId': _newRequestId(),
      'queryType': 'getPreferences',
      'payload': const <String, Object?>{},
    }),
  );

  @override
  Future<NotificationChannelSettings> update({
    required int expectedRevision,
    required String category,
    bool? inApp,
    bool? push,
  }) async {
    final Map<String, Object?> channels = <String, Object?>{
      if (inApp != null) 'inApp': inApp,
      if (push != null) 'push': push,
    };
    if (channels.isEmpty) {
      throw const NotificationsInboxFailure('request_invalid');
    }
    final String requestId = _newRequestId();
    return _parse(
      await _port.command(<String, Object?>{
        'schemaVersion': 1,
        'requestId': requestId,
        // One logical change per tap; a retry of the same tap reuses it.
        'idempotencyKey': 'prefs-$requestId',
        'commandType': 'updatePreferences',
        'payload': <String, Object?>{
          'expectedRevision': expectedRevision,
          'categories': <String, Object?>{category: channels},
        },
      }),
    );
  }

  @override
  Future<void> sendTestNotification() async {
    final Map<String, Object?> answer = await _selfTest(<String, Object?>{
      'schemaVersion': 1,
      'requestId': _newRequestId(),
    });
    if (answer['kind'] != 'succeeded') {
      final Object? code = answer['code'];
      throw NotificationsInboxFailure(code is String ? code : 'answer_invalid');
    }
  }

  static NotificationChannelSettings _parse(Map<String, Object?> answer) {
    if (answer['kind'] != 'succeeded') {
      final Object? code = answer['code'];
      throw NotificationsInboxFailure(code is String ? code : 'answer_invalid');
    }
    final Object? revision = answer['revision'];
    final Object? categories = answer['categories'];
    if (revision is! int || categories is! List) {
      throw const NotificationsInboxFailure('answer_invalid');
    }
    return NotificationChannelSettings(
      revision: revision,
      categories: categories.map(_category).toList(growable: false),
    );
  }

  static NotificationCategoryChannels _category(Object? raw) {
    if (raw is! Map) throw const NotificationsInboxFailure('answer_invalid');
    final Object? category = raw['category'];
    final Object? inApp = raw['inApp'];
    final Object? push = raw['push'];
    if (category is! String ||
        inApp is! Map ||
        inApp['enabled'] is! bool ||
        inApp['locked'] is! bool ||
        (push != null && (push is! Map || push['enabled'] is! bool))) {
      throw const NotificationsInboxFailure('answer_invalid');
    }
    return NotificationCategoryChannels(
      category: category,
      inAppEnabled: inApp['enabled']! as bool,
      inAppLocked: inApp['locked']! as bool,
      pushEnabled: push == null ? null : (push as Map)['enabled']! as bool,
    );
  }
}
