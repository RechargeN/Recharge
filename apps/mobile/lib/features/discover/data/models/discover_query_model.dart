import '../../domain/entities/discover_query.dart';
import '../../domain/entities/time_window.dart';

/// The single local record mapper; domain values do not own storage shapes.
class DiscoverQueryModel {
  static Map<String, Object?> toMap(DiscoverQuery value) => <String, Object?>{
    'query_text': value.queryText,
    'selected_category_ids': value.selectedCategoryIds,
    'selected_subcategory_ids': value.selectedSubcategoryIds,
    'date_from': value.dateFrom?.toIso8601String(),
    'date_to': value.dateTo?.toIso8601String(),
    'people_count': value.peopleCount,
    'available_duration_minutes': value.availableDurationMinutes,
    'mood': value.mood,
    'budget_min': value.budgetMin,
    'budget_max': value.budgetMax,
    'free_only': value.freeOnly,
    'center_lat': value.centerLat,
    'center_lng': value.centerLng,
    'radius_meters': value.radiusMeters,
    'unlimited_radius': value.unlimitedRadius,
    'sort_mode': value.sortMode.name,
    'open_now': value.openNow,
    'only_available': value.onlyAvailable,
    'market_city_id': value.marketCityId,
    'manual_area_selected': value.manualAreaSelected,
    'search_area_dirty': value.searchAreaDirty,
    'source_screen': value.sourceScreen,
    'query_version': 2,
    'applied_at_utc': value.appliedAtUtc.toIso8601String(),
    'time_window': value.timeWindow?.toMap(),
    'travel_context': value.travelContext?.toMap(),
  };

  static DiscoverQuery fromMap(
    Map<String, Object?> map, {
    required String defaultMarketCityId,
    required double defaultCenterLat,
    required double defaultCenterLng,
  }) {
    final int sourceVersion = (map['query_version'] as num?)?.toInt() ?? 1;
    final bool manualAreaSelected =
        (map['manual_area_selected'] as bool?) ?? false;
    String marketCityId =
        (map['market_city_id'] as String?) ?? defaultMarketCityId;
    double centerLat =
        (map['center_lat'] as num?)?.toDouble() ?? defaultCenterLat;
    double centerLng =
        (map['center_lng'] as num?)?.toDouble() ?? defaultCenterLng;
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
