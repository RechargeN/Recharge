import 'time_window.dart';

enum DiscoverSortMode { geoFreshness }

class DiscoverQuery {
  DiscoverQuery({
    required this.queryText,
    required this.selectedCategoryIds,
    required this.selectedSubcategoryIds,
    required this.dateFrom,
    required this.dateTo,
    required this.peopleCount,
    this.availableDurationMinutes,
    this.mood,
    required this.budgetMin,
    required this.budgetMax,
    required this.freeOnly,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.unlimitedRadius,
    required this.sortMode,
    required this.openNow,
    required this.onlyAvailable,
    required this.marketCityId,
    required this.manualAreaSelected,
    required this.searchAreaDirty,
    required this.sourceScreen,
    required this.queryVersion,
    required this.appliedAtUtc,
    this.timeWindow,
    this.travelContext,
  }) {
    if (timeWindow != null && travelContext == null) {
      throw ArgumentError('travelContext is required with timeWindow');
    }
  }

  factory DiscoverQuery.defaults({
    String marketCityId = '',
    double centerLat = 0,
    double centerLng = 0,
    DateTime? nowUtc,
  }) => DiscoverQuery(
    queryText: '',
    selectedCategoryIds: const <String>[],
    selectedSubcategoryIds: const <String>[],
    dateFrom: null,
    dateTo: null,
    peopleCount: null,
    availableDurationMinutes: null,
    mood: null,
    budgetMin: null,
    budgetMax: null,
    freeOnly: false,
    centerLat: centerLat,
    centerLng: centerLng,
    radiusMeters: 5000,
    unlimitedRadius: false,
    sortMode: DiscoverSortMode.geoFreshness,
    openNow: false,
    onlyAvailable: false,
    marketCityId: marketCityId,
    manualAreaSelected: false,
    searchAreaDirty: false,
    sourceScreen: 'discover',
    queryVersion: 2,
    appliedAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
  );

  final String queryText;
  final List<String> selectedCategoryIds;
  final List<String> selectedSubcategoryIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? peopleCount;
  final int? availableDurationMinutes;
  final String? mood;
  final double? budgetMin;
  final double? budgetMax;
  final bool freeOnly;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final bool unlimitedRadius;
  final DiscoverSortMode sortMode;
  final bool openNow;
  final bool onlyAvailable;
  final String marketCityId;
  final bool manualAreaSelected;
  final bool searchAreaDirty;
  final String sourceScreen;
  final int queryVersion;
  final DateTime appliedAtUtc;
  final TimeWindow? timeWindow;
  final TravelContext? travelContext;

  bool get requestsPublishedRoutes {
    final source = sourceScreen.trim().toLowerCase();
    return queryText.trim().isNotEmpty ||
        selectedCategoryIds.isNotEmpty ||
        selectedSubcategoryIds.isNotEmpty ||
        freeOnly ||
        budgetMin != null ||
        budgetMax != null ||
        availableDurationMinutes != null ||
        manualAreaSelected ||
        source == 'regular_search' ||
        source == 'smart_search' ||
        source == 'search_results' ||
        source == 'map_search' ||
        source == 'route_details';
  }

  DiscoverQuery copyWith({
    String? queryText,
    List<String>? selectedCategoryIds,
    List<String>? selectedSubcategoryIds,
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
    double? budgetMin,
    bool clearBudgetMin = false,
    double? budgetMax,
    bool clearBudgetMax = false,
    bool? freeOnly,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    bool? unlimitedRadius,
    DiscoverSortMode? sortMode,
    bool? openNow,
    bool? onlyAvailable,
    String? marketCityId,
    bool? manualAreaSelected,
    bool? searchAreaDirty,
    String? sourceScreen,
    int? queryVersion,
    DateTime? appliedAtUtc,
    TimeWindow? timeWindow,
    bool clearTimeWindow = false,
    TravelContext? travelContext,
    bool clearTravelContext = false,
  }) => DiscoverQuery(
    queryText: queryText ?? this.queryText,
    selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
    selectedSubcategoryIds:
        selectedSubcategoryIds ?? this.selectedSubcategoryIds,
    dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
    dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    peopleCount: clearPeopleCount ? null : (peopleCount ?? this.peopleCount),
    availableDurationMinutes: clearAvailableDurationMinutes
        ? null
        : (availableDurationMinutes ?? this.availableDurationMinutes),
    mood: clearMood ? null : (mood ?? this.mood),
    budgetMin: clearBudgetMin ? null : (budgetMin ?? this.budgetMin),
    budgetMax: clearBudgetMax ? null : (budgetMax ?? this.budgetMax),
    freeOnly: freeOnly ?? this.freeOnly,
    centerLat: centerLat ?? this.centerLat,
    centerLng: centerLng ?? this.centerLng,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    unlimitedRadius: unlimitedRadius ?? this.unlimitedRadius,
    sortMode: sortMode ?? this.sortMode,
    openNow: openNow ?? this.openNow,
    onlyAvailable: onlyAvailable ?? this.onlyAvailable,
    marketCityId: marketCityId ?? this.marketCityId,
    manualAreaSelected: manualAreaSelected ?? this.manualAreaSelected,
    searchAreaDirty: searchAreaDirty ?? this.searchAreaDirty,
    sourceScreen: sourceScreen ?? this.sourceScreen,
    queryVersion: queryVersion ?? this.queryVersion,
    appliedAtUtc: appliedAtUtc ?? this.appliedAtUtc,
    timeWindow: clearTimeWindow ? null : (timeWindow ?? this.timeWindow),
    travelContext: clearTravelContext
        ? null
        : (travelContext ?? this.travelContext),
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'query_text': queryText,
    'selected_category_ids': selectedCategoryIds,
    'selected_subcategory_ids': selectedSubcategoryIds,
    'date_from': dateFrom?.toIso8601String(),
    'date_to': dateTo?.toIso8601String(),
    'people_count': peopleCount,
    'available_duration_minutes': availableDurationMinutes,
    'mood': mood,
    'budget_min': budgetMin,
    'budget_max': budgetMax,
    'free_only': freeOnly,
    'center_lat': centerLat,
    'center_lng': centerLng,
    'radius_meters': radiusMeters,
    'unlimited_radius': unlimitedRadius,
    'sort_mode': sortMode.name,
    'open_now': openNow,
    'only_available': onlyAvailable,
    'market_city_id': marketCityId,
    'manual_area_selected': manualAreaSelected,
    'search_area_dirty': searchAreaDirty,
    'source_screen': sourceScreen,
    'query_version': 2,
    'applied_at_utc': appliedAtUtc.toIso8601String(),
    'time_window': timeWindow?.toMap(),
    'travel_context': travelContext?.toMap(),
  };

  factory DiscoverQuery.fromMap(
    Map<String, Object?> map, {
    required String defaultMarketCityId,
    required double defaultCenterLat,
    required double defaultCenterLng,
  }) {
    final int sourceVersion = (map['query_version'] as num?)?.toInt() ?? 1;
    final bool manualAreaSelected =
        (map['manual_area_selected'] as bool?) ?? false;
    String marketCityId = (map['market_city_id'] as String?) ?? 'riga';
    double centerLat = (map['center_lat'] as num?)?.toDouble() ?? 56.9496;
    double centerLng = (map['center_lng'] as num?)?.toDouble() ?? 24.1052;
    final bool brokenLegacyDefault =
        sourceVersion < 2 &&
        !manualAreaSelected &&
        marketCityId == 'rezekne' &&
        centerLat == 56.5099 &&
        centerLng == 27.3332;
    if (brokenLegacyDefault) {
      marketCityId = defaultMarketCityId;
      centerLat = defaultCenterLat;
      centerLng = defaultCenterLng;
    }
    final Map<String, Object?>? timeWindowMap = _mapOrNull(map['time_window']);
    final Map<String, Object?>? travelContextMap = _mapOrNull(
      map['travel_context'],
    );
    return DiscoverQuery(
      queryText: (map['query_text'] as String?) ?? '',
      selectedCategoryIds:
          (map['selected_category_ids'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      selectedSubcategoryIds:
          (map['selected_subcategory_ids'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      dateFrom: _dateOrNull(map['date_from']),
      dateTo: _dateOrNull(map['date_to']),
      peopleCount: (map['people_count'] as num?)?.toInt(),
      availableDurationMinutes: (map['available_duration_minutes'] as num?)
          ?.toInt(),
      mood: map['mood'] as String?,
      budgetMin: (map['budget_min'] as num?)?.toDouble(),
      budgetMax: (map['budget_max'] as num?)?.toDouble(),
      freeOnly: (map['free_only'] as bool?) ?? false,
      centerLat: centerLat,
      centerLng: centerLng,
      radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 5000,
      unlimitedRadius: (map['unlimited_radius'] as bool?) ?? false,
      sortMode: DiscoverSortMode.values.firstWhere(
        (DiscoverSortMode value) => value.name == map['sort_mode'],
        orElse: () => DiscoverSortMode.geoFreshness,
      ),
      openNow: (map['open_now'] as bool?) ?? false,
      onlyAvailable: (map['only_available'] as bool?) ?? false,
      marketCityId: marketCityId,
      manualAreaSelected: manualAreaSelected,
      searchAreaDirty: (map['search_area_dirty'] as bool?) ?? false,
      sourceScreen: (map['source_screen'] as String?) ?? 'discover',
      queryVersion: 2,
      appliedAtUtc:
          _dateOrNull(map['applied_at_utc']) ?? DateTime.now().toUtc(),
      timeWindow: sourceVersion < 2 || timeWindowMap == null
          ? null
          : TimeWindow.fromMap(timeWindowMap),
      travelContext: sourceVersion < 2 || travelContextMap == null
          ? null
          : TravelContext.fromMap(travelContextMap),
    );
  }
}

DateTime? _dateOrNull(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value).toUtc() : null;

Map<String, Object?>? _mapOrNull(Object? value) =>
    value is Map<dynamic, dynamic>
    ? value.map(
        (dynamic key, dynamic nested) =>
            MapEntry<String, Object?>(key as String, nested as Object?),
      )
    : null;
