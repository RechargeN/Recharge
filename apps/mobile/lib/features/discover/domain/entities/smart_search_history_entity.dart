import 'discover_query.dart';

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
}
