import '../../domain/entities/location_search_suggestion.dart';
import '../../domain/repositories/location_search_repository.dart';
import '../datasources/google_places_search_datasource.dart';

class LocationSearchResolutionFailure implements Exception {
  const LocationSearchResolutionFailure(this.suggestionId);

  final String suggestionId;

  @override
  String toString() =>
      'LocationSearchResolutionFailure(could not resolve $suggestionId)';
}

class LocationSearchRepositoryImpl implements LocationSearchRepository {
  const LocationSearchRepositoryImpl(this._datasource);

  final GooglePlacesSearchDatasource _datasource;

  @override
  Future<List<LocationSearchSuggestion>> search(
    String query, {
    required String marketCityId,
  }) {
    // marketCityId biasing is not wired into the Places API request yet —
    // the New API expects a locationBias region/circle, not a free-text
    // city id; left as plain autocomplete until a canonical
    // city-id -> lat/lng/radius lookup exists (out of scope for this pass).
    return _datasource.autocomplete(query);
  }

  @override
  Future<LocationSearchResolution> resolve(String suggestionId) async {
    final ({String formattedAddress, double latitude, double longitude})?
    details = await _datasource.placeDetails(suggestionId);
    if (details == null) {
      throw LocationSearchResolutionFailure(suggestionId);
    }
    return LocationSearchResolution(
      formattedAddress: details.formattedAddress,
      latitude: details.latitude,
      longitude: details.longitude,
    );
  }
}
