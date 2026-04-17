import '../../application/queries/discover_query.dart';
import '../../domain/repositories/discover_preferences_repository.dart';
import '../datasources/discover_preferences_local_datasource.dart';

class DiscoverPreferencesRepositoryImpl implements DiscoverPreferencesRepository {
  DiscoverPreferencesRepositoryImpl({
    required DiscoverPreferencesLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final DiscoverPreferencesLocalDataSource _localDataSource;

  @override
  Future<DiscoverQuery?> loadLastQuery() {
    return _localDataSource.loadLastQuery();
  }

  @override
  Future<void> saveLastQuery(DiscoverQuery query) {
    return _localDataSource.saveLastQuery(query);
  }
}

