import '../../domain/entities/discover_item_entity.dart';
import '../queries/discover_query.dart';

enum DiscoverFeedStatus {
  initial,
  loading,
  ready,
  empty,
  error,
  permissionDenied,
  selectingArea,
  denseCluster,
}

class DiscoverFeedState {
  const DiscoverFeedState({
    required this.status,
    required this.items,
    required this.message,
    required this.appliedQuery,
    required this.draftQuery,
    required this.searchAreaDirty,
    required this.selectedItemId,
    required this.resultCount,
  });

  factory DiscoverFeedState.initial() {
    final DiscoverQuery query = DiscoverQuery.defaults();
    return DiscoverFeedState(
      status: DiscoverFeedStatus.initial,
      items: const <DiscoverItemEntity>[],
      message: null,
      appliedQuery: query,
      draftQuery: query,
      searchAreaDirty: false,
      selectedItemId: null,
      resultCount: 0,
    );
  }

  final DiscoverFeedStatus status;
  final List<DiscoverItemEntity> items;
  final String? message;
  final DiscoverQuery appliedQuery;
  final DiscoverQuery draftQuery;
  final bool searchAreaDirty;
  final String? selectedItemId;
  final int resultCount;

  DiscoverItemEntity? get selectedItem {
    if (selectedItemId == null) return null;
    for (final DiscoverItemEntity item in items) {
      if (item.id == selectedItemId) return item;
    }
    return null;
  }

  bool get isDenseCluster => resultCount > 40;
  bool get canShowRawMarkers => resultCount <= 120;

  DiscoverFeedState copyWith({
    DiscoverFeedStatus? status,
    List<DiscoverItemEntity>? items,
    String? message,
    bool clearMessage = false,
    DiscoverQuery? appliedQuery,
    DiscoverQuery? draftQuery,
    bool? searchAreaDirty,
    String? selectedItemId,
    bool clearSelectedItem = false,
    int? resultCount,
  }) {
    return DiscoverFeedState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: clearMessage ? null : (message ?? this.message),
      appliedQuery: appliedQuery ?? this.appliedQuery,
      draftQuery: draftQuery ?? this.draftQuery,
      searchAreaDirty: searchAreaDirty ?? this.searchAreaDirty,
      selectedItemId:
          clearSelectedItem ? null : (selectedItemId ?? this.selectedItemId),
      resultCount: resultCount ?? this.resultCount,
    );
  }
}

