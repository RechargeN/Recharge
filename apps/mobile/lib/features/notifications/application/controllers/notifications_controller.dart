import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/notification_item_entity.dart';
import '../../domain/usecases/get_notifications_usecase.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';
import '../state/notifications_state.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({
    required GetNotificationsUseCase getNotificationsUseCase,
    required MarkNotificationReadUseCase markNotificationReadUseCase,
    required AnalyticsService analyticsService,
  })  : _getNotificationsUseCase = getNotificationsUseCase,
        _markNotificationReadUseCase = markNotificationReadUseCase,
        _analyticsService = analyticsService;

  final GetNotificationsUseCase _getNotificationsUseCase;
  final MarkNotificationReadUseCase _markNotificationReadUseCase;
  final AnalyticsService _analyticsService;

  NotificationsState _state = NotificationsState.initial();
  NotificationsState get state => _state;

  String? _loadedUserId;

  Future<void> ensureLoaded({
    required String userId,
  }) async {
    if (_loadedUserId == userId && _state.status == NotificationsStatus.ready) {
      return;
    }
    _loadedUserId = userId;
    await loadNotifications(userId: userId);
  }

  Future<void> loadNotifications({
    required String userId,
  }) async {
    _setState(
      _state.copyWith(
        status: NotificationsStatus.loading,
        clearMessage: true,
      ),
    );
    try {
      final List<NotificationItemEntity> items =
          await _getNotificationsUseCase(userId: userId);
      items.sort(
        (NotificationItemEntity a, NotificationItemEntity b) =>
            b.createdAtUtc.compareTo(a.createdAtUtc),
      );
      _setState(
        _state.copyWith(
          status: NotificationsStatus.ready,
          items: items,
          clearMessage: true,
        ),
      );
      _analyticsService.track(
        'notifications_loaded',
        params: <String, Object?>{
          'user_id': userId,
          'item_count': items.length,
          'unread_count': _state.unreadCount,
        },
      );
    } on Exception {
      _setState(
        _state.copyWith(
          status: NotificationsStatus.error,
          message: 'Не удалось загрузить уведомления',
        ),
      );
      _analyticsService.track(
        'notifications_load_failed',
        params: const <String, Object?>{
          'error_group': 'storage',
        },
      );
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final String? userId = _loadedUserId;
    if (userId == null) return;

    NotificationItemEntity? target;
    for (final NotificationItemEntity item in _state.items) {
      if (item.id == notificationId) {
        target = item;
        break;
      }
    }
    if (target == null || target.isRead) {
      return;
    }

    _analyticsService.track(
      'notifications_mark_read_started',
      params: <String, Object?>{
        'notification_id': notificationId,
      },
    );

    await _markNotificationReadUseCase(
      userId: userId,
      notificationId: notificationId,
    );

    final List<NotificationItemEntity> updated =
        _state.items.map((NotificationItemEntity item) {
      if (item.id == notificationId) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList(growable: false);

    _setState(
      _state.copyWith(
        status: NotificationsStatus.ready,
        items: updated,
      ),
    );
    _analyticsService.track(
      'notifications_mark_read_succeeded',
      params: <String, Object?>{
        'notification_id': notificationId,
      },
    );
  }

  void _setState(NotificationsState state) {
    _state = state;
    notifyListeners();
  }
}
