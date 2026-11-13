import '../entities/location_search_suggestion.dart';
import '../repositories/location_search_repository.dart';

/// Guards the repository call with a minimum query length so every
/// keystroke does not spend API quota — the caller (coordinator/controller)
/// is still responsible for debouncing keystroke timing itself.
class SearchLocationSuggestionsUseCase {
  const SearchLocationSuggestionsUseCase(
    this._repository, {
    this.minQueryLength = 3,
  });

  final LocationSearchRepository _repository;
  final int minQueryLength;

  Future<List<LocationSearchSuggestion>> call(
    String query, {
    required String marketCityId,
  }) {
    final String trimmed = query.trim();
    if (trimmed.length < minQueryLength) {
      return Future<List<LocationSearchSuggestion>>.value(
        const <LocationSearchSuggestion>[],
      );
    }
    return _repository.search(trimmed, marketCityId: marketCityId);
  }
}
