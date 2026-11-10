import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/favorite_item_entity.dart';
import '../../domain/usecases/add_favorite_usecase.dart';
import '../../domain/usecases/get_favorites_usecase.dart';
import '../../domain/usecases/remove_favorite_usecase.dart';
import '../state/favorites_state.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController({
    required GetFavoritesUseCase getFavoritesUseCase,
    required AddFavoriteUseCase addFavoriteUseCase,
    required RemoveFavoriteUseCase removeFavoriteUseCase,
    required AnalyticsService analyticsService,
  }) : _getFavoritesUseCase = getFavoritesUseCase,
       _addFavoriteUseCase = addFavoriteUseCase,
       _removeFavoriteUseCase = removeFavoriteUseCase,
       _analyticsService = analyticsService;

  final GetFavoritesUseCase _getFavoritesUseCase;
  final AddFavoriteUseCase _addFavoriteUseCase;
  final RemoveFavoriteUseCase _removeFavoriteUseCase;
  final AnalyticsService _analyticsService;

  FavoritesState _state = FavoritesState.initial();
  FavoritesState get state => _state;

  bool _requestedOnce = false;

  Future<void> ensureLoaded() async {
    if (_requestedOnce) return;
    _requestedOnce = true;
    await loadFavorites();
  }

  Future<void> loadFavorites() async {
    _setState(
      _state.copyWith(status: FavoritesStatus.loading, clearMessage: true),
    );
    try {
      final List<FavoriteItemEntity> favorites = await _getFavoritesUseCase();
      _setState(
        _state.copyWith(
          status: FavoritesStatus.ready,
          items: favorites,
          clearMessage: true,
        ),
      );
      _analyticsService.track(
        'favorites_loaded',
        params: <String, Object?>{'item_count': favorites.length},
      );
    } on Object {
      _setState(
        _state.copyWith(
          status: FavoritesStatus.error,
          message: 'Не удалось загрузить избранное',
        ),
      );
      _analyticsService.track(
        'favorites_load_failed',
        params: const <String, Object?>{'error_group': 'storage'},
      );
    }
  }

  bool isFavorite(String itemId) {
    return _state.favoriteIds.contains(itemId);
  }

  Future<bool> addFavorite(
    FavoriteItemEntity item, {
    required String sourceScreen,
  }) async {
    try {
      _analyticsService.track(
        'favorites_add_started',
        params: <String, Object?>{
          'source_screen': sourceScreen,
          'item_id': item.id,
        },
      );
      await _addFavoriteUseCase(item);
      await loadFavorites();
      if (_state.status == FavoritesStatus.error) return false;
      _analyticsService.track(
        'favorites_add_succeeded',
        params: <String, Object?>{
          'source_screen': sourceScreen,
          'item_id': item.id,
        },
      );
      return true;
    } on Object {
      _setState(
        _state.copyWith(
          status: FavoritesStatus.error,
          message: 'Не удалось завершить сохранение избранного.',
        ),
      );
      return false;
    }
  }

  Future<bool> removeFavorite(
    String itemId, {
    required String sourceScreen,
  }) async {
    try {
      _analyticsService.track(
        'favorites_remove_started',
        params: <String, Object?>{
          'source_screen': sourceScreen,
          'item_id': itemId,
        },
      );
      await _removeFavoriteUseCase(itemId);
      await loadFavorites();
      if (_state.status == FavoritesStatus.error) return false;
      _analyticsService.track(
        'favorites_remove_succeeded',
        params: <String, Object?>{
          'source_screen': sourceScreen,
          'item_id': itemId,
        },
      );
      return true;
    } on Object {
      _setState(
        _state.copyWith(
          status: FavoritesStatus.error,
          message: 'Не удалось завершить сохранение избранного.',
        ),
      );
      return false;
    }
  }

  Future<bool> toggleFavorite(
    FavoriteItemEntity item, {
    required String sourceScreen,
  }) async {
    if (isFavorite(item.id)) {
      return removeFavorite(item.id, sourceScreen: sourceScreen);
    }
    return addFavorite(item, sourceScreen: sourceScreen);
  }

  void _setState(FavoritesState state) {
    _state = state;
    notifyListeners();
  }
}
