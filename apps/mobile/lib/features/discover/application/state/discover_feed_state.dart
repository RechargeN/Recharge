import '../../domain/entities/discover_item_entity.dart';

enum DiscoverFeedStatus {
  initial,
  loading,
  success,
  empty,
  error,
}

class DiscoverFeedState {
  const DiscoverFeedState({
    required this.status,
    required this.items,
    required this.message,
  });

  const DiscoverFeedState.initial()
      : status = DiscoverFeedStatus.initial,
        items = const <DiscoverItemEntity>[],
        message = null;

  final DiscoverFeedStatus status;
  final List<DiscoverItemEntity> items;
  final String? message;

  DiscoverFeedState copyWith({
    DiscoverFeedStatus? status,
    List<DiscoverItemEntity>? items,
    String? message,
    bool clearMessage = false,
  }) {
    return DiscoverFeedState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

