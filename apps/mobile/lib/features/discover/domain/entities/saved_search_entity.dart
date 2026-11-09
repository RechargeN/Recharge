import 'discover_query.dart';

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
}
