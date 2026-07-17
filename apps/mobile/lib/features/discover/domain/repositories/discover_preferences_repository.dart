import '../entities/discover_query.dart';
import '../entities/saved_search_entity.dart';
import '../entities/smart_search_history_entity.dart';

abstract class DiscoverPreferencesRepository {
  Future<void> saveLastQuery(DiscoverQuery query);
  Future<DiscoverQuery?> loadLastQuery();
  Future<List<SavedSearchEntity>> loadSavedSearches();
  Future<void> saveSavedSearch(SavedSearchEntity search);
  Future<void> deleteSavedSearch(String id);
  Future<List<SmartSearchHistoryEntity>> loadSmartSearchHistory();
  Future<void> saveSmartSearchPrompt(SmartSearchHistoryEntity item);
  Future<void> deleteSmartSearchPrompt(String id);
}
