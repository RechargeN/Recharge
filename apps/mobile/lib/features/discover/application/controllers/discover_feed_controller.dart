import 'package:flutter/foundation.dart';

import '../../../../core/config/recharge_taxonomy.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/discover_query.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/time_window.dart';
import '../../domain/entities/time_fit_evaluation.dart';
import '../../domain/entities/saved_search_entity.dart';
import '../../domain/entities/smart_search_history_entity.dart';
import '../../domain/repositories/discover_preferences_repository.dart';
import '../../domain/repositories/discover_repository.dart';
import '../../domain/usecases/get_discover_feed_usecase.dart';
import '../../domain/usecases/build_time_window_usecase.dart';
import '../discover_runtime_defaults.dart';
import '../state/discover_feed_state.dart';

enum TimeFitRelaxation { widenWindow, skipReturnTrip, removeTimeFilter }

class DiscoverFeedController extends ChangeNotifier {
  DiscoverFeedController({
    required GetDiscoverFeedUseCase getDiscoverFeedUseCase,
    required DiscoverPreferencesRepository discoverPreferencesRepository,
    required AnalyticsService analyticsService,
    DiscoverQuery? initialQuery,
    BuildTimeWindowUseCase? buildTimeWindow,
    DiscoverRuntimeDefaults runtimeDefaults = const DiscoverRuntimeDefaults(
      timezoneId: 'UTC',
      originLat: 0,
      originLng: 0,
    ),
  }) : _getDiscoverFeedUseCase = getDiscoverFeedUseCase,
       _discoverPreferencesRepository = discoverPreferencesRepository,
       _analyticsService = analyticsService,
       _initialQuery = initialQuery ?? DiscoverQuery.defaults(),
       _buildTimeWindow = buildTimeWindow,
       _runtimeDefaults = runtimeDefaults,
       _state = DiscoverFeedState.initial(
         initialQuery ?? DiscoverQuery.defaults(),
       );

  final GetDiscoverFeedUseCase _getDiscoverFeedUseCase;
  final DiscoverPreferencesRepository _discoverPreferencesRepository;
  final AnalyticsService _analyticsService;
  final DiscoverQuery _initialQuery;
  final BuildTimeWindowUseCase? _buildTimeWindow;
  final DiscoverRuntimeDefaults _runtimeDefaults;

  String get marketTimezoneId => _runtimeDefaults.timezoneId;

  DiscoverFeedState _state;
  DiscoverFeedState get state => _state;

  bool _requestedOnce = false;
  bool _savedSearchesRequested = false;
  bool _smartSearchHistoryRequested = false;

  void beginSearchDraft() {
    _setState(_state.copyWith(draftQuery: _state.appliedQuery));
  }

  void stageSearchConditions({
    String? queryText,
    int? peopleCount,
    bool clearPeopleCount = false,
    double? budgetMax,
    bool clearBudgetMax = false,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    double? radiusMeters,
    bool? unlimitedRadius,
    bool? openNow,
    bool? onlyAvailable,
    int? availableDurationMinutes,
    bool clearAvailableDurationMinutes = false,
    String? mood,
    bool clearMood = false,
    TimeWindow? timeWindow,
    bool clearTimeWindow = false,
    TravelContext? travelContext,
    bool clearTravelContext = false,
  }) {
    _setState(
      _state.copyWith(
        draftQuery: _state.draftQuery.copyWith(
          queryText: queryText?.trim(),
          peopleCount: peopleCount,
          clearPeopleCount: clearPeopleCount,
          budgetMax: budgetMax,
          clearBudgetMax: clearBudgetMax,
          dateFrom: dateFrom?.toUtc(),
          clearDateFrom: clearDateFrom,
          dateTo: dateTo?.toUtc(),
          clearDateTo: clearDateTo,
          radiusMeters: radiusMeters,
          unlimitedRadius: unlimitedRadius,
          openNow: openNow,
          onlyAvailable: onlyAvailable,
          availableDurationMinutes: availableDurationMinutes,
          clearAvailableDurationMinutes: clearAvailableDurationMinutes,
          mood: mood,
          clearMood: clearMood,
          timeWindow: timeWindow,
          clearTimeWindow: clearTimeWindow,
          travelContext: travelContext,
          clearTravelContext: clearTravelContext,
        ),
      ),
    );
  }

  String? stageTimeWindowSelection({
    required TimeWindowMode mode,
    DateTime? startLocal,
    DateTime? endLocal,
    required int flexibilityMinutes,
    required TravelOriginType originType,
    double? originLat,
    double? originLng,
    required TransportMode transportMode,
    required bool includeReturnTrip,
  }) {
    final BuildTimeWindowUseCase? builder = _buildTimeWindow;
    if (builder == null) return 'Time-window service is unavailable';
    try {
      final TimeWindow timeWindow = builder(
        mode: mode,
        timezoneId: _runtimeDefaults.timezoneId,
        nowUtc: DateTime.now().toUtc(),
        startLocal: startLocal,
        endLocal: endLocal,
        flexibilityMinutes: flexibilityMinutes,
      );
      final TravelContext travelContext = TravelContext(
        originType: originType,
        origin: GeoPoint(
          latitude: originLat ?? _runtimeDefaults.originLat,
          longitude: originLng ?? _runtimeDefaults.originLng,
        ),
        transportMode: transportMode,
        includeReturnTrip: includeReturnTrip,
      );
      stageSearchConditions(
        timeWindow: timeWindow,
        travelContext: travelContext,
        dateFrom: timeWindow.startAtUtc,
        dateTo: timeWindow.endAtUtc,
      );
      _analyticsService.track(
        'time_window_applied',
        params: <String, Object?>{
          'mode': mode.name,
          'transport_mode': transportMode.name,
          'include_return_trip': includeReturnTrip,
        },
      );
      return null;
    } on TimeWindowValidationException catch (error) {
      return error.message;
    } on ArgumentError catch (error) {
      return error.message?.toString() ?? 'Invalid travel context';
    }
  }

  void clearTimeWindowSelection({bool clearLegacyDates = true}) {
    stageSearchConditions(
      clearTimeWindow: true,
      clearTravelContext: true,
      clearDateFrom: clearLegacyDates,
      clearDateTo: clearLegacyDates,
    );
  }

  Future<void> applyTimeFitRelaxation(TimeFitRelaxation relaxation) async {
    final DiscoverQuery query = _state.appliedQuery;
    final TimeWindow? window = query.timeWindow;
    if (window == null) return;

    DiscoverQuery relaxed;
    switch (relaxation) {
      case TimeFitRelaxation.widenWindow:
        final int flexibility = window.mode == TimeWindowMode.flexible
            ? (window.flexibilityMinutes + 15).clamp(15, 60)
            : 30;
        relaxed = query.copyWith(
          timeWindow: TimeWindow(
            startAtUtc: window.startAtUtc,
            endAtUtc: window.endAtUtc,
            timezoneId: window.timezoneId,
            mode: TimeWindowMode.flexible,
            flexibilityMinutes: flexibility,
            resolvedAtUtc: DateTime.now().toUtc(),
          ),
        );
      case TimeFitRelaxation.skipReturnTrip:
        final TravelContext? travel = query.travelContext;
        if (travel == null || !travel.includeReturnTrip) return;
        relaxed = query.copyWith(
          travelContext: TravelContext(
            originType: travel.originType,
            origin: travel.origin,
            transportMode: travel.transportMode,
            includeReturnTrip: false,
          ),
        );
      case TimeFitRelaxation.removeTimeFilter:
        relaxed = query.copyWith(
          clearTimeWindow: true,
          clearTravelContext: true,
          clearDateFrom: true,
          clearDateTo: true,
        );
    }
    _analyticsService.track(
      'time_fit_relaxation_selected',
      params: <String, Object?>{'relaxation': relaxation.name},
    );
    await _applyGlobalQueryUpdate(
      relaxed.copyWith(queryVersion: 2, appliedAtUtc: DateTime.now().toUtc()),
      clearSelectedItem: true,
    );
  }

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
      _state.copyWith(status: DiscoverFeedStatus.loading, clearMessage: true),
    );

    try {
      final List<DiscoverItemEntity> items = await _getDiscoverFeedUseCase(
        _state.appliedQuery,
      );
      if (_state.appliedQuery.timeWindow != null) {
        final int unknownCount = items
            .where(
              (DiscoverItemEntity item) =>
                  item.timeFitEvaluation?.timeFitStatus ==
                  TimeFitStatus.unknown,
            )
            .length;
        _analyticsService.track(
          'time_fit_result_shown',
          params: <String, Object?>{
            'item_count': items.length,
            'unknown_count': unknownCount,
          },
        );
        if (unknownCount > 0) {
          _analyticsService.track(
            'time_fit_unknown_shown',
            params: <String, Object?>{'item_count': unknownCount},
          );
        }
        final int failedTravelCount = items
            .where(
              (DiscoverItemEntity item) =>
                  item.timeFitEvaluation?.quality ==
                  TravelEstimateQuality.unavailable,
            )
            .length;
        if (failedTravelCount > 0) {
          _analyticsService.track(
            'travel_estimate_failed',
            params: <String, Object?>{'item_count': failedTravelCount},
          );
        }
      }

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
          params: const <String, Object?>{'result': 'empty', 'item_count': 0},
        );
        return;
      }

      final DiscoverFeedStatus nextStatus = items.length > 40
          ? DiscoverFeedStatus.denseCluster
          : DiscoverFeedStatus.ready;

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
        queryVersion: 2,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> setCategoryFilter(String? categoryId) async {
    final List<String> categories = categoryId == null
        ? <String>[]
        : <String>[categoryId];
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        selectedCategoryIds: categories,
        selectedSubcategoryIds: const <String>[],
        queryVersion: 2,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<Map<String, int>> loadCategoryResultCounts() async {
    await ensureLoaded();
    final DiscoverQuery countQuery = _state.appliedQuery.copyWith(
      selectedCategoryIds: const <String>[],
      selectedSubcategoryIds: const <String>[],
    );
    final List<DiscoverItemEntity> items = await _getDiscoverFeedUseCase(
      countQuery,
    );
    final Map<String, int> counts = <String, int>{};
    for (final DiscoverItemEntity item in items) {
      final String categoryId = normalizeRechargeContentGroupId(item.category);
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> setFreeOnly(bool enabled) async {
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        freeOnly: enabled,
        queryVersion: 2,
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
        queryVersion: 2,
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
        queryVersion: 2,
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

  Future<void> recordRecentSearch(DiscoverQuery query) async {
    final SavedSearchEntity search = _savedSearchForQuery(query);
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
    final DiscoverQuery refreshed = _refreshAnytimeToday(search.query);
    final DiscoverQuery query = refreshed.copyWith(
      queryVersion: 2,
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
    final SmartSearchHistoryEntity? item = _smartSearchHistoryForQuery(
      prompt,
      query,
    );
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
    final DiscoverQuery refreshed = _refreshAnytimeToday(item.query);
    final DiscoverQuery query = refreshed.copyWith(
      queryVersion: 2,
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
    List<String>? selectedSubcategoryIds,
    bool? freeOnly,
    double? budgetMin,
    bool clearBudgetMin = false,
    double? budgetMax,
    bool clearBudgetMax = false,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    int? peopleCount,
    bool clearPeopleCount = false,
    int? availableDurationMinutes,
    bool clearAvailableDurationMinutes = false,
    String? mood,
    bool clearMood = false,
    String? sourceScreen,
    double? radiusMeters,
    bool? unlimitedRadius,
    bool? openNow,
    bool? onlyAvailable,
    double? centerLat,
    double? centerLng,
    bool? manualAreaSelected,
    String? selectedItemId,
    TimeWindow? timeWindow,
    bool clearTimeWindow = false,
    TravelContext? travelContext,
    bool clearTravelContext = false,
  }) async {
    await _applyGlobalQueryUpdate(
      _state.appliedQuery.copyWith(
        queryText: queryText?.trim(),
        selectedCategoryIds: selectedCategoryIds,
        selectedSubcategoryIds: selectedSubcategoryIds,
        freeOnly: freeOnly,
        budgetMin: budgetMin,
        clearBudgetMin: clearBudgetMin,
        budgetMax: budgetMax,
        clearBudgetMax: clearBudgetMax,
        dateFrom: dateFrom?.toUtc(),
        clearDateFrom: clearDateFrom,
        dateTo: dateTo?.toUtc(),
        clearDateTo: clearDateTo,
        peopleCount: peopleCount,
        clearPeopleCount: clearPeopleCount,
        availableDurationMinutes: availableDurationMinutes,
        clearAvailableDurationMinutes: clearAvailableDurationMinutes,
        mood: mood,
        clearMood: clearMood,
        sourceScreen: sourceScreen,
        radiusMeters: radiusMeters,
        unlimitedRadius: unlimitedRadius,
        openNow: openNow,
        onlyAvailable: onlyAvailable,
        centerLat: centerLat,
        centerLng: centerLng,
        manualAreaSelected: manualAreaSelected,
        timeWindow: timeWindow,
        clearTimeWindow: clearTimeWindow,
        travelContext: travelContext,
        clearTravelContext: clearTravelContext,
        queryVersion: 2,
        appliedAtUtc: DateTime.now().toUtc(),
      ),
      selectedItemId: selectedItemId,
    );
  }

  Future<void> resetSearchConditions() async {
    final DiscoverQuery defaults = _initialQuery.copyWith(
      appliedAtUtc: DateTime.now().toUtc(),
    );
    await _applyGlobalQueryUpdate(
      defaults.copyWith(queryVersion: 2, appliedAtUtc: DateTime.now().toUtc()),
    );
  }

  void stageMapCenter({required double lat, required double lng}) {
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

  void stageRadius({required double radiusMeters, required bool unlimited}) {
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
      sourceScreen: 'map_search',
      queryVersion: 2,
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
    // MVP baseline: mock current location at the active market center.
    stageMapCenter(lat: _initialQuery.centerLat, lng: _initialQuery.centerLng);
    await applySearchArea();
  }

  void recenterToAppliedArea() {
    _setState(
      _state.copyWith(draftQuery: _state.appliedQuery, searchAreaDirty: false),
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
    final DiscoverQuery? lastQuery = await _discoverPreferencesRepository
        .loadLastQuery();
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

  DiscoverQuery _refreshAnytimeToday(DiscoverQuery query) {
    if (query.timeWindow?.mode != TimeWindowMode.anytimeToday ||
        _buildTimeWindow == null) {
      return query;
    }
    try {
      final TimeWindow refreshed = _buildTimeWindow(
        mode: TimeWindowMode.anytimeToday,
        timezoneId: query.timeWindow!.timezoneId,
        nowUtc: DateTime.now().toUtc(),
      );
      return query.copyWith(
        timeWindow: refreshed,
        dateFrom: refreshed.startAtUtc,
        dateTo: refreshed.endAtUtc,
      );
    } on TimeWindowValidationException {
      return query;
    }
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
    if (query.budgetMax != null) 'up to ${query.budgetMax!.toStringAsFixed(0)}',
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
  return rechargeTaxonomyLabel(categoryId);
}
