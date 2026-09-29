import '../entities/location_search_suggestion.dart';
import '../repositories/location_search_repository.dart';

class ResolveLocationSuggestionUseCase {
  const ResolveLocationSuggestionUseCase(this._repository);

  final LocationSearchRepository _repository;

  Future<LocationSearchResolution> call(String suggestionId) {
    return _repository.resolve(suggestionId);
  }
}
