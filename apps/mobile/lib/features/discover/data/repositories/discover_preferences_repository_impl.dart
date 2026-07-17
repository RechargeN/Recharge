import '../../domain/entities/discover_query.dart';
import '../../domain/entities/saved_search_entity.dart';
import '../../domain/entities/smart_search_history_entity.dart';
import '../../domain/repositories/discover_preferences_repository.dart';
import '../datasources/discover_preferences_local_datasource.dart';

class DiscoverPreferencesRepositoryImpl
    implements DiscoverPreferencesRepository {
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

  @override
  Future<List<SavedSearchEntity>> loadSavedSearches() {
    return _localDataSource.loadSavedSearches();
  }

  @override
  Future<void> saveSavedSearch(SavedSearchEntity search) {
    return _localDataSource.saveSavedSearch(search);
  }

  @override
  Future<void> deleteSavedSearch(String id) {
    return _localDataSource.deleteSavedSearch(id);
  }

  @override
  Future<List<SmartSearchHistoryEntity>> loadSmartSearchHistory() {
    return _localDataSource.loadSmartSearchHistory();
  }

  @override
  Future<void> saveSmartSearchPrompt(SmartSearchHistoryEntity item) {
    return _localDataSource.saveSmartSearchPrompt(item);
  }

  @override
  Future<void> deleteSmartSearchPrompt(String id) {
    return _localDataSource.deleteSmartSearchPrompt(id);
  }
}
