enum NotificationType {
  system,
  reminder,
  activity,
}

class NotificationItemEntity {
  const NotificationItemEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAtUtc,
    required this.isRead,
    required this.targetRoute,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAtUtc;
  final bool isRead;
  final String? targetRoute;

  NotificationItemEntity copyWith({
    bool? isRead,
  }) {
    return NotificationItemEntity(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAtUtc: createdAtUtc,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute,
    );
  }
}
