import '../../application/queries/discover_query.dart';

class SavedSearchEntity {
  const SavedSearchEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.createdAtUtc,
  });

  final String id;
  final String title;
  final String subtitle;
  final DiscoverQuery query;
  final DateTime createdAtUtc;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'query': query.toMap(),
      'created_at_utc': createdAtUtc.toIso8601String(),
    };
  }

  factory SavedSearchEntity.fromMap(Map<String, Object?> map) {
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
      query: DiscoverQuery.fromMap(queryMap),
      createdAtUtc: map['created_at_utc'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(map['created_at_utc']! as String).toUtc(),
    );
  }
}
