import '../entities/location_search_suggestion.dart';

/// Provider-agnostic place/area search used by Create's Place identity step
/// and Collection's area-anchor step. Bounded to authoring-time UX only —
/// this is not Discover's search/ranking pipeline.
abstract class LocationSearchRepository {
  /// Returns candidate suggestions for [query], biased toward
  /// [marketCityId] where the provider supports it. Implementations must
  /// degrade to an empty list on any failure (missing/invalid API key,
  /// network error, rate limit) rather than throwing — the map-tap fallback
  /// always remains available regardless of search availability.
  Future<List<LocationSearchSuggestion>> search(
    String query, {
    required String marketCityId,
  });

  /// Resolves a previously returned suggestion's [suggestionId] into a
  /// concrete point + formatted address.
  Future<LocationSearchResolution> resolve(String suggestionId);
}
