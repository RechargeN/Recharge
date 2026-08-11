import '../../domain/entities/notification_item_entity.dart';

enum NotificationsStatus { initial, loading, ready, error }

class NotificationsState {
  const NotificationsState({
    required this.status,
    required this.items,
    required this.searchResults,
    required this.searchQuery,
    required this.message,
  });

  factory NotificationsState.initial() {
    return const NotificationsState(
      status: NotificationsStatus.initial,
      items: <NotificationItemEntity>[],
      searchResults: <NotificationItemEntity>[],
      searchQuery: '',
      message: null,
    );
  }

  final NotificationsStatus status;
  final List<NotificationItemEntity> items;
  final List<NotificationItemEntity> searchResults;
  final String searchQuery;
  final String? message;

  int get unreadCount {
    return items.where((NotificationItemEntity item) => !item.isRead).length;
  }

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationItemEntity>? items,
    List<NotificationItemEntity>? searchResults,
    String? searchQuery,
    String? message,
    bool clearMessage = false,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
