import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/notification_item_model.dart';

class NotificationsLocalDataSource {
  NotificationsLocalDataSource(this._storage);

  final FlutterSecureStorage _storage;

  String _notificationsKey(String userId) => 'notifications_items_$userId';

  Future<List<NotificationItemModel>> readNotifications(String userId) async {
    final String? raw = await _storage.read(key: _notificationsKey(userId));
    if (raw == null || raw.isEmpty) return const <NotificationItemModel>[];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => NotificationItemModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const <NotificationItemModel>[];
    }
  }

  Future<void> writeNotifications(
    String userId,
    List<NotificationItemModel> items,
  ) {
    final String raw = jsonEncode(
      items
          .map((NotificationItemModel item) => item.toJson())
          .toList(growable: false),
    );
    return _storage.write(key: _notificationsKey(userId), value: raw);
  }
}
