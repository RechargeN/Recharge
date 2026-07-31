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
  }) : _getNotificationsUseCase = getNotificationsUseCase,
       _markNotificationReadUseCase = markNotificationReadUseCase,
       _analyticsService = analyticsService;

  final GetNotificationsUseCase _getNotificationsUseCase;
  final MarkNotificationReadUseCase _markNotificationReadUseCase;
  final AnalyticsService _analyticsService;

  NotificationsState _state = NotificationsState.initial();
  NotificationsState get state => _state;

  String? _loadedUserId;

  Future<void> ensureLoaded({required String userId}) async {
    if (_loadedUserId == userId && _state.status == NotificationsStatus.ready) {
      return;
    }
    _loadedUserId = userId;
    await loadNotifications(userId: userId);
  }

  Future<void> loadNotifications({required String userId}) async {
    _setState(
      _state.copyWith(status: NotificationsStatus.loading, clearMessage: true),
    );
    try {
      final List<NotificationItemEntity> items = await _getNotificationsUseCase(
        userId: userId,
      );
      items.sort(
        (NotificationItemEntity a, NotificationItemEntity b) =>
            b.createdAtUtc.compareTo(a.createdAtUtc),
      );
      _setState(
        _state.copyWith(
          status: NotificationsStatus.ready,
          items: items,
          searchResults: _search(items, _state.searchQuery),
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
        params: const <String, Object?>{'error_group': 'storage'},
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
      params: <String, Object?>{'notification_id': notificationId},
    );

    await _markNotificationReadUseCase(
      userId: userId,
      notificationId: notificationId,
    );

    final List<NotificationItemEntity> updated = _state.items
        .map((NotificationItemEntity item) {
          if (item.id == notificationId) {
            return item.copyWith(isRead: true);
          }
          return item;
        })
        .toList(growable: false);

    _setState(
      _state.copyWith(
        status: NotificationsStatus.ready,
        items: updated,
        searchResults: _search(updated, _state.searchQuery),
      ),
    );
    _analyticsService.track(
      'notifications_mark_read_succeeded',
      params: <String, Object?>{'notification_id': notificationId},
    );
  }

  Future<void> markAllAsRead() async {
    final String? userId = _loadedUserId;
    if (userId == null) return;

    final List<String> unreadIds = _state.items
        .where((NotificationItemEntity item) => !item.isRead)
        .map((NotificationItemEntity item) => item.id)
        .toList(growable: false);
    if (unreadIds.isEmpty) return;

    _analyticsService.track(
      'notifications_mark_all_read_started',
      params: <String, Object?>{'unread_count': unreadIds.length},
    );

    for (final String notificationId in unreadIds) {
      await _markNotificationReadUseCase(
        userId: userId,
        notificationId: notificationId,
      );
    }

    final Set<String> unreadIdSet = unreadIds.toSet();
    final List<NotificationItemEntity> updated = _state.items
        .map((NotificationItemEntity item) {
          if (unreadIdSet.contains(item.id)) {
            return item.copyWith(isRead: true);
          }
          return item;
        })
        .toList(growable: false);

    _setState(
      _state.copyWith(
        status: NotificationsStatus.ready,
        items: updated,
        searchResults: _search(updated, _state.searchQuery),
      ),
    );
    _analyticsService.track(
      'notifications_mark_all_read_succeeded',
      params: <String, Object?>{'marked_count': unreadIds.length},
    );
  }

  void updateSearchQuery(String value) {
    final String query = value.trim();
    _setState(
      _state.copyWith(
        searchQuery: query,
        searchResults: _search(_state.items, query),
      ),
    );
    _analyticsService.track(
      'notifications_search_changed',
      params: <String, Object?>{
        'query_length': query.length,
        'result_count': _state.searchResults.length,
      },
    );
  }

  void clearSearch() {
    updateSearchQuery('');
  }

  List<NotificationItemEntity> _search(
    List<NotificationItemEntity> items,
    String query,
  ) {
    final List<String> terms = _normalizeSearchText(query)
        .split(' ')
        .where((String term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) return items;

    return items
        .where((NotificationItemEntity item) {
          final String searchable = _normalizeSearchText(
            <String>[
              item.title,
              item.body,
              _typeSearchText(item.type),
            ].join(' '),
          );
          final List<String> tokens = searchable
              .split(' ')
              .where((String token) => token.isNotEmpty)
              .toList(growable: false);
          return terms.every(
            (String term) => _matchesSearchTerm(
              term: term,
              searchable: searchable,
              tokens: tokens,
            ),
          );
        })
        .toList(growable: false);
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s*:\s*'), ':')
        .replaceAll(
          RegExp(r'[^a-z0-9а-я:]+', caseSensitive: false, unicode: true),
          ' ',
        )
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _typeSearchText(NotificationType type) {
    return switch (type) {
      NotificationType.system => 'system системное система',
      NotificationType.reminder => 'reminder напоминание',
      NotificationType.activity => 'activity активность обновление',
    };
  }

  bool _matchesSearchTerm({
    required String term,
    required String searchable,
    required List<String> tokens,
  }) {
    if (searchable.contains(term)) return true;
    if (term.contains(':') || int.tryParse(term) != null) return false;

    final int maxDistance = switch (term.runes.length) {
      <= 3 => 0,
      <= 6 => 1,
      _ => 2,
    };
    if (maxDistance == 0) return false;

    return tokens.any((String token) {
      if ((token.runes.length - term.runes.length).abs() > maxDistance) {
        return false;
      }
      return _damerauLevenshteinDistance(term, token) <= maxDistance;
    });
  }

  int _damerauLevenshteinDistance(String left, String right) {
    final List<int> a = left.runes.toList(growable: false);
    final List<int> b = right.runes.toList(growable: false);
    final List<List<int>> distance = List<List<int>>.generate(
      a.length + 1,
      (int row) => List<int>.filled(b.length + 1, 0),
      growable: false,
    );

    for (int row = 0; row <= a.length; row++) {
      distance[row][0] = row;
    }
    for (int column = 0; column <= b.length; column++) {
      distance[0][column] = column;
    }

    for (int row = 1; row <= a.length; row++) {
      for (int column = 1; column <= b.length; column++) {
        final int substitutionCost = a[row - 1] == b[column - 1] ? 0 : 1;
        int value = _minimum(
          distance[row - 1][column] + 1,
          distance[row][column - 1] + 1,
          distance[row - 1][column - 1] + substitutionCost,
        );
        if (row > 1 &&
            column > 1 &&
            a[row - 1] == b[column - 2] &&
            a[row - 2] == b[column - 1]) {
          value = value < distance[row - 2][column - 2] + 1
              ? value
              : distance[row - 2][column - 2] + 1;
        }
        distance[row][column] = value;
      }
    }
    return distance[a.length][b.length];
  }

  int _minimum(int first, int second, int third) {
    final int pairMinimum = first < second ? first : second;
    return pairMinimum < third ? pairMinimum : third;
  }

  void _setState(NotificationsState state) {
    _state = state;
    notifyListeners();
  }
}
