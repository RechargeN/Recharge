import '../../domain/entities/smart_search_history_entity.dart';
import 'discover_query_model.dart';

/// The single local record mapper; domain values do not own storage shapes.
class SmartSearchHistoryModel {
  static Map<String, Object?> toMap(SmartSearchHistoryEntity value) {
    return <String, Object?>{
      'id': value.id,
      'prompt': value.prompt,
      'query': DiscoverQueryModel.toMap(value.query),
      'created_at_utc': value.createdAtUtc.toIso8601String(),
    };
  }

  static SmartSearchHistoryEntity fromMap(
    Map<String, Object?> map, {
    required String defaultMarketCityId,
    required double defaultCenterLat,
    required double defaultCenterLng,
    String? legacyCurrencyCode,
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

    return SmartSearchHistoryEntity(
      id: (map['id'] as String?) ?? 'smart_legacy',
      prompt: (map['prompt'] as String?) ?? '',
      query: DiscoverQueryModel.fromMap(
        queryMap,
        defaultMarketCityId: defaultMarketCityId,
        defaultCenterLat: defaultCenterLat,
        defaultCenterLng: defaultCenterLng,
        legacyCurrencyCode: legacyCurrencyCode,
      ),
      createdAtUtc: map['created_at_utc'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(map['created_at_utc']! as String).toUtc(),
    );
  }
}
