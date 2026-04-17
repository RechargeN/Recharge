import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/repositories/discover_preferences_repository.dart';
import '../../domain/repositories/discover_repository.dart';
import '../../domain/usecases/get_discover_feed_usecase.dart';
import '../queries/discover_query.dart';
import '../state/discover_feed_state.dart';

class DiscoverFeedController extends ChangeNotifier {
  DiscoverFeedController({
    required GetDiscoverFeedUseCase getDiscoverFeedUseCase,
    required DiscoverPreferencesRepository discoverPreferencesRepository,
    required AnalyticsService analyticsService,
  })  : _getDiscoverFeedUseCase = getDiscoverFeedUseCase,
        _discoverPreferencesRepository = discoverPreferencesRepository,
        _analyticsService = analyticsService;

  final GetDiscoverFeedUseCase _getDiscoverFeedUseCase;
  final DiscoverPreferencesRepository _discoverPreferencesRepository;
  final AnalyticsService _analyticsService;

  DiscoverFeedState _state = DiscoverFeedState.initial();
  DiscoverFeedState get state => _state;

  bool _requestedOnce = false;

  Future<void> ensureLoaded() async {
    if (_requestedOnce) return;
    _requestedOnce = true;
    await _restoreLastQuery();
    await loadFeed();
  }

  Future<void> loadFeed() async {
    if (_state.status == DiscoverFeedStatus.loading) return;

    _analyticsService.track(
      'discover_feed_load_started',
      params: <String, Object?>{
        'source_screen': _state.appliedQuery.sourceScreen,
        'query_version': _state.appliedQuery.queryVersion,
      },
    );

    _setState(
      _state.copyWith(
        status: DiscoverFeedStatus.loading,
        clearMessage: true,
      ),
    );

    try {
      final List<DiscoverItemEntity> items =
          await _getDiscoverFeedUseCase(_state.appliedQuery);

      if (items.isEmpty) {
        _setState(
          _state.copyWith(
            status: DiscoverFeedStatus.empty,
            items: const <DiscoverItemEntity>[],
            message:
                'Ничего не найдено в этой зоне. Попробуйте увеличить радиус или снять ограничения.',
            resultCount: 0,
            clearSelectedItem: true,
          ),
        );
        _analyticsService.track(
          'discover_feed_loaded',
          params: const <String, Object?>{
            'result': 'empty',
            'item_count': 0,
          },
        );
        return;
      }

      final DiscoverFeedStatus nextStatus =
          items.length > 40 ? DiscoverFeedStatus.denseCluster : DiscoverFeedStatus.ready;

      _setState(
        _state.copyWith(
          status: nextStatus,
          items: items,
          resultCount: items.length,
          clearMessage: true,
        ),
      );
      _analyticsService.track(
        'discover_feed_loaded',
        params: <String, Object?>{
          'result': nextStatus == DiscoverFeedStatus.denseCluster
              ? 'dense_cluster'
              : 'ready',
          'item_count': items.length,
        },
      );
    } on DiscoverException catch (e) {
      _setState(
        _state.copyWith(
          status: DiscoverFeedStatus.error,
          items: const <DiscoverItemEntity>[],
          message: _messageForErrorCode(e.code),
          resultCount: 0,
          clearSelectedItem: true,
        ),
      );
      _analyticsService.track(
        'discover_feed_load_failed',
        params: <String, Object?>{
          'error_code': e.code,
          'error_group': _errorGroup(e.code),
        },
      );
    } on Exception {
      _setState(
        _state.copyWith(
          status: DiscoverFeedStatus.error,
          items: const <DiscoverItemEntity>[],
          message: 'Не удалось загрузить данные. Попробуйте снова.',
          resultCount: 0,
          clearSelectedItem: true,
        ),
      );
      _analyticsService.track(
        'discover_feed_load_failed',
        params: const <String, Object?>{
          'error_code': 'UNEXPECTED',
          'error_group': 'server',
        },
      );
    }
  }

  Future<void> updateSearchText(String text) async {
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        queryText: text.trim(),
        queryVersion: _state.appliedQuery.queryVersion + 1,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> setCategoryFilter(String? categoryId) async {
    final List<String> categories =
        categoryId == null ? <String>[] : <String>[categoryId];
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        selectedCategoryIds: categories,
        queryVersion: _state.appliedQuery.queryVersion + 1,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> setFreeOnly(bool enabled) async {
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        freeOnly: enabled,
        queryVersion: _state.appliedQuery.queryVersion + 1,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> setBudgetRange({
    required double? min,
    required double? max,
  }) async {
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        budgetMin: min,
        clearBudgetMin: min == null,
        budgetMax: max,
        clearBudgetMax: max == null,
        queryVersion: _state.appliedQuery.queryVersion + 1,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> setDateRange({
    required DateTime? from,
    required DateTime? to,
  }) async {
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        dateFrom: from?.toUtc(),
        clearDateFrom: from == null,
        dateTo: to?.toUtc(),
        clearDateTo: to == null,
        queryVersion: _state.appliedQuery.queryVersion + 1,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void stageMapCenter({
    required double lat,
    required double lng,
  }) {
    _setState(
      _state.copyWith(
        status: DiscoverFeedStatus.selectingArea,
        draftQuery: _state.draftQuery.copyWith(
          centerLat: lat,
          centerLng: lng,
          manualAreaSelected: true,
          searchAreaDirty: true,
        ),
        searchAreaDirty: true,
      ),
    );
  }

  void stageRadius({
    required double radiusMeters,
    required bool unlimited,
  }) {
    _setState(
      _state.copyWith(
        status: DiscoverFeedStatus.selectingArea,
        draftQuery: _state.draftQuery.copyWith(
          radiusMeters: radiusMeters,
          unlimitedRadius: unlimited,
          searchAreaDirty: true,
        ),
        searchAreaDirty: true,
      ),
    );
  }

  Future<void> applySearchArea() async {
    final DiscoverQuery applied = _state.draftQuery.copyWith(
      searchAreaDirty: false,
      queryVersion: _state.appliedQuery.queryVersion + 1,
      appliedAtUtc: DateTime.now().toUtc(),
    );
    _setState(
      _state.copyWith(
        appliedQuery: applied,
        draftQuery: applied,
        searchAreaDirty: false,
      ),
    );
    await _discoverPreferencesRepository.saveLastQuery(applied);
    await loadFeed();
  }

  Future<void> useCurrentLocation() async {
    // MVP baseline: mock current location near city center.
    stageMapCenter(lat: 56.5099, lng: 27.3332);
    await applySearchArea();
  }

  void recenterToAppliedArea() {
    _setState(
      _state.copyWith(
        draftQuery: _state.appliedQuery,
        searchAreaDirty: false,
      ),
    );
  }

  void selectItem(String? itemId) {
    _setState(
      _state.copyWith(
        selectedItemId: itemId,
        clearSelectedItem: itemId == null,
      ),
    );
  }

  Future<void> _applyGlobalQueryUpdate(DiscoverQuery appliedQuery) async {
    _setState(
      _state.copyWith(
        appliedQuery: appliedQuery,
        draftQuery: appliedQuery,
        searchAreaDirty: false,
      ),
    );
    await _discoverPreferencesRepository.saveLastQuery(appliedQuery);
    await loadFeed();
  }

  Future<void> _restoreLastQuery() async {
    final DiscoverQuery? lastQuery =
        await _discoverPreferencesRepository.loadLastQuery();
    if (lastQuery == null) return;
    _setState(
      _state.copyWith(
        appliedQuery: lastQuery,
        draftQuery: lastQuery,
        searchAreaDirty: false,
      ),
    );
  }

  String _messageForErrorCode(String code) {
    switch (code) {
      case 'DISCOVER_NOT_FOUND':
        return 'Данные недоступны';
      case 'NETWORK_UNAVAILABLE':
        return 'Нет подключения к интернету';
      default:
        return 'Не удалось загрузить ленту. Попробуйте снова.';
    }
  }

  String _errorGroup(String code) {
    if (code.contains('NETWORK')) return 'network';
    if (code.contains('NOT_FOUND')) return 'data';
    return 'server';
  }

  void _setState(DiscoverFeedState state) {
    _state = state;
    notifyListeners();
  }
}

