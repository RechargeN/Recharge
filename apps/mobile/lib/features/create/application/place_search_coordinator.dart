import '../domain/entities/location_search_suggestion.dart';
import '../domain/usecases/resolve_location_suggestion_usecase.dart';
import '../domain/usecases/search_location_suggestions_usecase.dart';

/// Bridges Place's identity step to the shared location-search
/// infrastructure. Stateless by design (mirrors `PlaceEnrichmentCoordinator`)
/// — the in-flight suggestions list and loading flag live on `CreateState`,
/// owned by `CreateController`, not here.
class PlaceSearchCoordinator {
  const PlaceSearchCoordinator({
    required SearchLocationSuggestionsUseCase search,
    required ResolveLocationSuggestionUseCase resolve,
  }) : _search = search,
       _resolve = resolve;

  final SearchLocationSuggestionsUseCase _search;
  final ResolveLocationSuggestionUseCase _resolve;

  Future<List<LocationSearchSuggestion>> search(
    String query, {
    required String marketCityId,
  }) {
    return _search(query, marketCityId: marketCityId);
  }

  Future<LocationSearchResolution> resolve(String suggestionId) {
    return _resolve(suggestionId);
  }
}
