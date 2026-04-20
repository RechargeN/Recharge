import '../../domain/entities/notification_item_entity.dart';

enum NotificationsStatus {
  initial,
  loading,
  ready,
  error,
}

class NotificationsState {
  const NotificationsState({
    required this.status,
    required this.items,
    required this.message,
  });

  factory NotificationsState.initial() {
    return const NotificationsState(
      status: NotificationsStatus.initial,
      items: <NotificationItemEntity>[],
      message: null,
    );
  }

  final NotificationsStatus status;
  final List<NotificationItemEntity> items;
  final String? message;

  int get unreadCount {
    return items.where((NotificationItemEntity item) => !item.isRead).length;
  }

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationItemEntity>? items,
    String? message,
    bool clearMessage = false,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
