import '../../domain/entities/saved_search_entity.dart';
import 'discover_query_model.dart';

/// The single local record mapper; domain values do not own storage shapes.
class SavedSearchModel {
  static Map<String, Object?> toMap(SavedSearchEntity value) {
    return <String, Object?>{
      'id': value.id,
      'title': value.title,
      'subtitle': value.subtitle,
      'query': DiscoverQueryModel.toMap(value.query),
      'created_at_utc': value.createdAtUtc.toIso8601String(),
    };
  }

  static SavedSearchEntity fromMap(
    Map<String, Object?> map, {
    required String defaultMarketCityId,
    required double defaultCenterLat,
    required double defaultCenterLng,
  }) {
    final Object? rawQuery = map['query'];
    final Map<String, Object?> queryMap;
    if (rawQuery is Map<dynamic, dynamic>) {
      queryMap = rawQuery.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, Object?>(key as String, value as Object?),
      );
    } else {
      queryMap = const <String, Object?>{};
    }

    return SavedSearchEntity(
      id: (map['id'] as String?) ?? 'search_legacy',
      title: (map['title'] as String?) ?? 'Saved search',
      subtitle: (map['subtitle'] as String?) ?? 'Nearby activities',
      query: DiscoverQueryModel.fromMap(
        queryMap,
        defaultMarketCityId: defaultMarketCityId,
        defaultCenterLat: defaultCenterLat,
        defaultCenterLng: defaultCenterLng,
      ),
      createdAtUtc: map['created_at_utc'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(map['created_at_utc']! as String).toUtc(),
    );
  }
}
