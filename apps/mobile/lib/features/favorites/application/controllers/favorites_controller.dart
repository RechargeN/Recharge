import 'package:flutter/foundation.dart';

import '../../../../core/product_analytics/product_analytics_contract.dart';
import '../../../../core/product_analytics/product_analytics_recorder.dart';
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
    ProductAnalyticsRecorder? productAnalytics,
  }) : _getFavoritesUseCase = getFavoritesUseCase,
       _addFavoriteUseCase = addFavoriteUseCase,
       _removeFavoriteUseCase = removeFavoriteUseCase,
       _analyticsService = analyticsService,
       _productAnalytics = productAnalytics;

  final GetFavoritesUseCase _getFavoritesUseCase;
  final AddFavoriteUseCase _addFavoriteUseCase;
  final RemoveFavoriteUseCase _removeFavoriteUseCase;
  final AnalyticsService _analyticsService;
  final ProductAnalyticsRecorder? _productAnalytics;

  FavoritesState _state = FavoritesState.initial();
  FavoritesState get state => _state;

  bool _requestedOnce = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

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
    } on Exception {
      _setState(
        _state.copyWith(
          status: FavoritesStatus.error,
          items: const [],
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

  Future<void> addFavorite(
    FavoriteItemEntity item, {
    required String sourceScreen,
  }) async {
    _analyticsService.track(
      'favorites_add_started',
      params: <String, Object?>{
        'source_screen': sourceScreen,
        'item_id': item.id,
      },
    );
    await _addFavoriteUseCase(item);
    await loadFavorites();
    _analyticsService.track(
      'favorites_add_succeeded',
      params: <String, Object?>{
        'source_screen': sourceScreen,
        'item_id': item.id,
      },
    );
    // L3 `favorite_added` v1: object type and surface only; not Library
    // evidence of the saved entry.
    final ProductAnalyticsObjectKind? kind =
        ProductAnalyticsObjectKind.fromObjectType(item.objectType);
    if (kind != null) {
      _productAnalytics?.record(
        FavoriteAdded(kind, _entrySurface(sourceScreen)),
      );
    }
  }

  static ProductAnalyticsEntrySurface _entrySurface(String sourceScreen) {
    return switch (sourceScreen) {
      'discover_details' => ProductAnalyticsEntrySurface.details,
      'discover_map' => ProductAnalyticsEntrySurface.map,
      'quick_plan' => ProductAnalyticsEntrySurface.planner,
      _ => ProductAnalyticsEntrySurface.other,
    };
  }

  Future<void> removeFavorite(
    String itemId, {
    required String sourceScreen,
  }) async {
    _analyticsService.track(
      'favorites_remove_started',
      params: <String, Object?>{
        'source_screen': sourceScreen,
        'item_id': itemId,
      },
    );
    await _removeFavoriteUseCase(itemId);
    await loadFavorites();
    _analyticsService.track(
      'favorites_remove_succeeded',
      params: <String, Object?>{
        'source_screen': sourceScreen,
        'item_id': itemId,
      },
    );
  }

  Future<void> toggleFavorite(
    FavoriteItemEntity item, {
    required String sourceScreen,
  }) async {
    if (isFavorite(item.id)) {
      await removeFavorite(item.id, sourceScreen: sourceScreen);
      return;
    }
    await addFavorite(item, sourceScreen: sourceScreen);
  }

  void _setState(FavoritesState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }
}
