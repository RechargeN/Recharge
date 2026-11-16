import '../../domain/entities/saved_search_entity.dart';
import 'discover_query_model.dart';
import '../../../../shared/primitives/time/utc_instant.dart';
import '../../domain/repositories/timezone_repository.dart';

/// The single local record mapper; domain values do not own storage shapes.
class SavedSearchModel {
  static Map<String, Object?> toMap(
    SavedSearchEntity value, {
    TimezoneRepository? timezoneRepository,
  }) {
    return <String, Object?>{
      'id': value.id,
      'title': value.title,
      'subtitle': value.subtitle,
      'query': DiscoverQueryModel.toMap(
        value.query,
        timezoneRepository: timezoneRepository,
      ),
      'created_at_utc': UtcInstant(value.createdAtUtc).toString(),
    };
  }

  static SavedSearchEntity fromMap(
    Map<String, Object?> map, {
    required String defaultMarketCityId,
    required double defaultCenterLat,
    required double defaultCenterLng,
    String? legacyCurrencyCode,
    TimezoneRepository? timezoneRepository,
  }) {
    final Object? rawQuery = map['query'];
    final Map<String, Object?> queryMap;
    if (rawQuery is Map<dynamic, dynamic>) {
      queryMap = rawQuery.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, Object?>(key as String, value as Object?),
      );
    } else {
      if (rawQuery != null) throw const FormatException('Invalid stored query');
      queryMap = const <String, Object?>{};
    }

    final created = map['created_at_utc'];
    if (created != null && created is! String) {
      throw const FormatException('Invalid created_at_utc');
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
        legacyCurrencyCode: legacyCurrencyCode,
        timezoneRepository: timezoneRepository,
      ),
      createdAtUtc: created == null
          ? DateTime.now().toUtc()
          : UtcInstant.parse(created as String).value,
    );
  }
}
