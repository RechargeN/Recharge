import '../../domain/entities/favorite_item_entity.dart';

enum FavoritesStatus {
  initial,
  loading,
  ready,
  error,
}

class FavoritesState {
  const FavoritesState({
    required this.status,
    required this.items,
    required this.message,
  });

  factory FavoritesState.initial() {
    return const FavoritesState(
      status: FavoritesStatus.initial,
      items: <FavoriteItemEntity>[],
      message: null,
    );
  }

  final FavoritesStatus status;
  final List<FavoriteItemEntity> items;
  final String? message;

  Set<String> get favoriteIds {
    return items.map((FavoriteItemEntity item) => item.id).toSet();
  }

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<FavoriteItemEntity>? items,
    String? message,
    bool clearMessage = false,
  }) {
    return FavoritesState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
