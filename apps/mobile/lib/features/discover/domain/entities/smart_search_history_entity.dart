import '../../application/queries/discover_query.dart';

class SmartSearchHistoryEntity {
  const SmartSearchHistoryEntity({
    required this.id,
    required this.prompt,
    required this.query,
    required this.createdAtUtc,
  });

  final String id;
  final String prompt;
  final DiscoverQuery query;
  final DateTime createdAtUtc;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'prompt': prompt,
      'query': query.toMap(),
      'created_at_utc': createdAtUtc.toIso8601String(),
    };
  }

  factory SmartSearchHistoryEntity.fromMap(Map<String, Object?> map) {
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

    return SmartSearchHistoryEntity(
      id: (map['id'] as String?) ?? 'smart_legacy',
      prompt: (map['prompt'] as String?) ?? '',
      query: DiscoverQuery.fromMap(queryMap),
      createdAtUtc: map['created_at_utc'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(map['created_at_utc']! as String).toUtc(),
    );
  }
}
