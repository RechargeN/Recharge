import '../../domain/entities/notification_item_entity.dart';

class NotificationItemModel {
  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAtUtcIso,
    required this.isRead,
    required this.targetRoute,
  });

  factory NotificationItemModel.fromEntity(NotificationItemEntity entity) {
    return NotificationItemModel(
      id: entity.id,
      title: entity.title,
      body: entity.body,
      type: entity.type.name,
      createdAtUtcIso: entity.createdAtUtc.toIso8601String(),
      isRead: entity.isRead,
      targetRoute: entity.targetRoute,
    );
  }

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      createdAtUtcIso: json['createdAtUtcIso'] as String,
      isRead: json['isRead'] as bool? ?? false,
      targetRoute: json['targetRoute'] as String?,
    );
  }

  final String id;
  final String title;
  final String body;
  final String type;
  final String createdAtUtcIso;
  final bool isRead;
  final String? targetRoute;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'createdAtUtcIso': createdAtUtcIso,
      'isRead': isRead,
      'targetRoute': targetRoute,
    };
  }

  NotificationItemEntity toEntity() {
    return NotificationItemEntity(
      id: id,
      title: title,
      body: body,
      type: _parseType(type),
      createdAtUtc: DateTime.parse(createdAtUtcIso).toUtc(),
      isRead: isRead,
      targetRoute: targetRoute,
    );
  }

  NotificationType _parseType(String value) {
    switch (value) {
      case 'reminder':
        return NotificationType.reminder;
      case 'activity':
        return NotificationType.activity;
      case 'system':
      default:
        return NotificationType.system;
    }
  }
}
