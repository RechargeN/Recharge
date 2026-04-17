import '../../application/queries/discover_query.dart';

abstract class DiscoverPreferencesRepository {
  Future<void> saveLastQuery(DiscoverQuery query);
  Future<DiscoverQuery?> loadLastQuery();
}

