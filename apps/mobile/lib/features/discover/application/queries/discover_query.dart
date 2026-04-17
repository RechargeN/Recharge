enum DiscoverSortMode {
  geoFreshness,
}

class DiscoverQuery {
  const DiscoverQuery({
    required this.queryText,
    required this.selectedCategoryIds,
    required this.selectedSubcategoryIds,
    required this.dateFrom,
    required this.dateTo,
    required this.peopleCount,
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
  });

  factory DiscoverQuery.defaults() {
    return DiscoverQuery(
      queryText: '',
      selectedCategoryIds: const <String>[],
      selectedSubcategoryIds: const <String>[],
      dateFrom: null,
      dateTo: null,
      peopleCount: null,
      budgetMin: null,
      budgetMax: null,
      freeOnly: false,
      centerLat: 56.5099,
      centerLng: 27.3332,
      radiusMeters: 5000,
      unlimitedRadius: false,
      sortMode: DiscoverSortMode.geoFreshness,
      openNow: false,
      onlyAvailable: false,
      marketCityId: 'rezekne',
      manualAreaSelected: false,
      searchAreaDirty: false,
      sourceScreen: 'discover',
      queryVersion: 1,
      appliedAtUtc: DateTime.now().toUtc(),
    );
  }

  final String queryText;
  final List<String> selectedCategoryIds;
  final List<String> selectedSubcategoryIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? peopleCount;
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
  }) {
    return DiscoverQuery(
      queryText: queryText ?? this.queryText,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      selectedSubcategoryIds:
          selectedSubcategoryIds ?? this.selectedSubcategoryIds,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      peopleCount: clearPeopleCount ? null : (peopleCount ?? this.peopleCount),
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
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'query_text': queryText,
      'selected_category_ids': selectedCategoryIds,
      'selected_subcategory_ids': selectedSubcategoryIds,
      'date_from': dateFrom?.toIso8601String(),
      'date_to': dateTo?.toIso8601String(),
      'people_count': peopleCount,
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
      'query_version': queryVersion,
      'applied_at_utc': appliedAtUtc.toIso8601String(),
    };
  }

  factory DiscoverQuery.fromMap(Map<String, Object?> map) {
    return DiscoverQuery(
      queryText: (map['query_text'] as String?) ?? '',
      selectedCategoryIds:
          (map['selected_category_ids'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      selectedSubcategoryIds:
          (map['selected_subcategory_ids'] as List<dynamic>? ?? <dynamic>[])
              .cast<String>(),
      dateFrom: map['date_from'] == null
          ? null
          : DateTime.parse(map['date_from']! as String),
      dateTo: map['date_to'] == null
          ? null
          : DateTime.parse(map['date_to']! as String),
      peopleCount: map['people_count'] as int?,
      budgetMin: (map['budget_min'] as num?)?.toDouble(),
      budgetMax: (map['budget_max'] as num?)?.toDouble(),
      freeOnly: (map['free_only'] as bool?) ?? false,
      centerLat: (map['center_lat'] as num?)?.toDouble() ?? 56.5099,
      centerLng: (map['center_lng'] as num?)?.toDouble() ?? 27.3332,
      radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 5000,
      unlimitedRadius: (map['unlimited_radius'] as bool?) ?? false,
      sortMode: DiscoverSortMode.values.firstWhere(
        (DiscoverSortMode value) => value.name == map['sort_mode'],
        orElse: () => DiscoverSortMode.geoFreshness,
      ),
      openNow: (map['open_now'] as bool?) ?? false,
      onlyAvailable: (map['only_available'] as bool?) ?? false,
      marketCityId: (map['market_city_id'] as String?) ?? 'rezekne',
      manualAreaSelected: (map['manual_area_selected'] as bool?) ?? false,
      searchAreaDirty: (map['search_area_dirty'] as bool?) ?? false,
      sourceScreen: (map['source_screen'] as String?) ?? 'discover',
      queryVersion: (map['query_version'] as int?) ?? 1,
      appliedAtUtc: map['applied_at_utc'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(map['applied_at_utc']! as String),
    );
  }
}

