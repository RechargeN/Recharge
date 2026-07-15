import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/saved_search_entity.dart';
import '../../domain/entities/smart_search_history_entity.dart';
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
  bool _savedSearchesRequested = false;
  bool _smartSearchHistoryRequested = false;

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

  Future<void> ensureSavedSearchesLoaded() async {
    if (_savedSearchesRequested) return;
    _savedSearchesRequested = true;
    final List<SavedSearchEntity> searches =
        await _discoverPreferencesRepository.loadSavedSearches();
    _setState(_state.copyWith(savedSearches: searches));
  }

  Future<void> ensureSmartSearchHistoryLoaded() async {
    if (_smartSearchHistoryRequested) return;
    _smartSearchHistoryRequested = true;
    final List<SmartSearchHistoryEntity> history =
        await _discoverPreferencesRepository.loadSmartSearchHistory();
    _setState(_state.copyWith(smartSearchHistory: history));
  }

  Future<void> saveCurrentSearch() async {
    final SavedSearchEntity search = _savedSearchForQuery(_state.appliedQuery);
    await _discoverPreferencesRepository.saveSavedSearch(search);
    final List<SavedSearchEntity> next = <SavedSearchEntity>[
      search,
      ..._state.savedSearches.where(
        (SavedSearchEntity item) => item.id != search.id,
      ),
    ].take(8).toList(growable: false);
    _setState(_state.copyWith(savedSearches: next));
  }

  Future<void> applySavedSearch(SavedSearchEntity search) async {
    final DiscoverQuery query = search.query.copyWith(
      queryVersion: _state.appliedQuery.queryVersion + 1,
      appliedAtUtc: DateTime.now().toUtc(),
    );
    await _applyGlobalQueryUpdate(query, clearSelectedItem: true);
  }

  Future<void> deleteSavedSearch(String id) async {
    await _discoverPreferencesRepository.deleteSavedSearch(id);
    _setState(
      _state.copyWith(
        savedSearches: _state.savedSearches
            .where((SavedSearchEntity item) => item.id != id)
            .toList(growable: false),
      ),
    );
  }

  Future<void> saveSmartSearchPrompt({
    required String prompt,
    required DiscoverQuery query,
  }) async {
    final SmartSearchHistoryEntity? item =
        _smartSearchHistoryForQuery(prompt, query);
    if (item == null) return;
    await _discoverPreferencesRepository.saveSmartSearchPrompt(item);
    final List<SmartSearchHistoryEntity> next = <SmartSearchHistoryEntity>[
      item,
      ..._state.smartSearchHistory.where(
        (SmartSearchHistoryEntity current) => current.id != item.id,
      ),
    ].take(6).toList(growable: false);
    _setState(_state.copyWith(smartSearchHistory: next));
  }

  Future<void> applySmartSearchHistory(SmartSearchHistoryEntity item) async {
    final DiscoverQuery query = item.query.copyWith(
      queryVersion: _state.appliedQuery.queryVersion + 1,
      appliedAtUtc: DateTime.now().toUtc(),
    );
    await _applyGlobalQueryUpdate(query, clearSelectedItem: true);
    await saveSmartSearchPrompt(prompt: item.prompt, query: query);
  }

  Future<void> deleteSmartSearchPrompt(String id) async {
    await _discoverPreferencesRepository.deleteSmartSearchPrompt(id);
    _setState(
      _state.copyWith(
        smartSearchHistory: _state.smartSearchHistory
            .where((SmartSearchHistoryEntity item) => item.id != id)
            .toList(growable: false),
      ),
    );
  }

  Future<void> applySearchConditions({
    String? queryText,
    List<String>? selectedCategoryIds,
    bool? freeOnly,
    double? budgetMin,
    bool clearBudgetMin = false,
    double? budgetMax,
    bool clearBudgetMax = false,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    double? radiusMeters,
    bool? unlimitedRadius,
    double? centerLat,
    double? centerLng,
    bool? manualAreaSelected,
    String? selectedItemId,
  }) async {
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        queryText: queryText?.trim(),
        selectedCategoryIds: selectedCategoryIds,
        freeOnly: freeOnly,
        budgetMin: budgetMin,
        clearBudgetMin: clearBudgetMin,
        budgetMax: budgetMax,
        clearBudgetMax: clearBudgetMax,
        dateFrom: dateFrom?.toUtc(),
        clearDateFrom: clearDateFrom,
        dateTo: dateTo?.toUtc(),
        clearDateTo: clearDateTo,
        radiusMeters: radiusMeters,
        unlimitedRadius: unlimitedRadius,
        centerLat: centerLat,
        centerLng: centerLng,
        manualAreaSelected: manualAreaSelected,
        queryVersion: _state.appliedQuery.queryVersion + 1,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
      selectedItemId: selectedItemId,
    );
  }

  Future<void> resetSearchConditions() async {
    final DiscoverQuery defaults = DiscoverQuery.defaults();
    await _applyGlobalQueryUpdate(
      defaults.copyWith(
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

  Future<void> _applyGlobalQueryUpdate(
    DiscoverQuery appliedQuery, {
    String? selectedItemId,
    bool clearSelectedItem = false,
  }) async {
    _setState(
      _state.copyWith(
        appliedQuery: appliedQuery,
        draftQuery: appliedQuery,
        searchAreaDirty: false,
        selectedItemId: selectedItemId,
        clearSelectedItem: clearSelectedItem,
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

SavedSearchEntity _savedSearchForQuery(DiscoverQuery query) {
  final DateTime now = DateTime.now().toUtc();
  return SavedSearchEntity(
    id: _savedSearchIdFor(query),
    title: _savedSearchTitleFor(query),
    subtitle: _savedSearchSubtitleFor(query),
    query: query.copyWith(appliedAtUtc: now),
    createdAtUtc: now,
  );
}

String _savedSearchIdFor(DiscoverQuery query) {
  final String raw = <String>[
    query.queryText.trim().toLowerCase(),
    query.selectedCategoryIds.join('-'),
    query.freeOnly ? 'free' : 'paid',
    query.budgetMax?.round().toString() ?? 'any_budget',
    query.dateFrom?.toIso8601String() ?? 'any_date',
    query.dateTo?.toIso8601String() ?? 'any_date_to',
    query.radiusMeters.round().toString(),
    query.unlimitedRadius ? 'any_area' : 'radius',
  ].join('_');
  final String sanitized = raw
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final int checksum = raw.codeUnits.fold<int>(
    0,
    (int value, int codeUnit) => (value + codeUnit) % 100000,
  );
  final String readable = sanitized.isEmpty
      ? 'custom'
      : sanitized.substring(0, sanitized.length > 72 ? 72 : sanitized.length);
  return 'search_${readable}_$checksum';
}

SmartSearchHistoryEntity? _smartSearchHistoryForQuery(
  String prompt,
  DiscoverQuery query,
) {
  final String trimmed = prompt.trim();
  if (trimmed.isEmpty) return null;
  final DateTime now = DateTime.now().toUtc();
  return SmartSearchHistoryEntity(
    id: _smartSearchHistoryIdFor(trimmed, query),
    prompt: trimmed,
    query: query.copyWith(appliedAtUtc: now),
    createdAtUtc: now,
  );
}

String _smartSearchHistoryIdFor(String prompt, DiscoverQuery query) {
  final String raw = <String>[
    prompt.trim().toLowerCase(),
    query.queryText.trim().toLowerCase(),
    query.selectedCategoryIds.join('-'),
    query.freeOnly ? 'free' : 'paid',
    query.budgetMax?.round().toString() ?? 'any_budget',
    query.radiusMeters.round().toString(),
    query.unlimitedRadius ? 'any_area' : 'radius',
  ].join('_');
  final String sanitized = raw
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final int checksum = raw.codeUnits.fold<int>(
    0,
    (int value, int codeUnit) => (value + codeUnit) % 100000,
  );
  final String readable = sanitized.isEmpty
      ? 'prompt'
      : sanitized.substring(0, sanitized.length > 72 ? 72 : sanitized.length);
  return 'smart_${readable}_$checksum';
}

String _savedSearchTitleFor(DiscoverQuery query) {
  final String text = query.queryText.trim();
  if (text.isNotEmpty) return _sentenceCase(text);
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${_categoryLabel(query.selectedCategoryIds.first)} nearby';
  }
  if (query.freeOnly) return 'Free nearby';
  return 'Nearby recharge';
}

String _savedSearchSubtitleFor(DiscoverQuery query) {
  final List<String> parts = <String>[
    if (query.selectedCategoryIds.isNotEmpty)
      _categoryLabel(query.selectedCategoryIds.first),
    if (query.freeOnly) 'free',
    if (query.budgetMax != null)
      'up to ${query.budgetMax!.toStringAsFixed(0)}',
    if (query.dateFrom != null || query.dateTo != null) 'date set',
    query.unlimitedRadius
        ? 'any area'
        : '${(query.radiusMeters / 1000).round()} km',
  ];
  return parts.isEmpty ? 'Nearby activities' : parts.join(' · ');
}

String _sentenceCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _categoryLabel(String categoryId) {
  switch (categoryId) {
    case 'outdoor':
      return 'Outdoor';
    case 'wellness':
      return 'Wellness';
    case 'art':
      return 'Art';
    case 'music':
      return 'Music';
    case 'family':
      return 'Family';
    default:
      return categoryId;
  }
}
