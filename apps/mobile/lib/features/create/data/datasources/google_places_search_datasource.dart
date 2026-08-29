import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/location_search_suggestion.dart';

/// Talks to Google Places API (New) directly over REST — no plugin
/// dependency, reuses the app's shared `http.Client`. Every method degrades
/// to an empty/failed result on any problem (missing key, network error,
/// non-2xx response, unparseable body) instead of throwing: search is an
/// authoring convenience, never a hard dependency of Create.
class GooglePlacesSearchDatasource {
  GooglePlacesSearchDatasource({required http.Client client, required String apiKey})
    : _client = client,
      _apiKey = apiKey;

  static const String _baseUrl = 'https://places.googleapis.com/v1';

  final http.Client _client;
  final String _apiKey;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<LocationSearchSuggestion>> autocomplete(String query) async {
    if (!isConfigured) return const <LocationSearchSuggestion>[];
    try {
      final http.Response response = await _client.post(
        Uri.parse('$_baseUrl/places:autocomplete'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
        },
        body: jsonEncode(<String, Object?>{'input': query}),
      );
      if (response.statusCode != 200) return const <LocationSearchSuggestion>[];
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        return const <LocationSearchSuggestion>[];
      }
      final Object? rawSuggestions = decoded['suggestions'];
      if (rawSuggestions is! List) return const <LocationSearchSuggestion>[];
      final List<LocationSearchSuggestion> results = <LocationSearchSuggestion>[];
      for (final Object? entry in rawSuggestions) {
        final LocationSearchSuggestion? suggestion = _parseSuggestion(entry);
        if (suggestion != null) results.add(suggestion);
      }
      return results;
    } catch (_) {
      return const <LocationSearchSuggestion>[];
    }
  }

  /// Returns `null` on any failure — the caller must not blindly overwrite
  /// an already-set draft location with a null-derived value.
  Future<({String formattedAddress, double latitude, double longitude})?>
  placeDetails(String placeId) async {
    if (!isConfigured) return null;
    try {
      final http.Response response = await _client.get(
        Uri.parse('$_baseUrl/places/$placeId'),
        headers: <String, String>{
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'formattedAddress,location',
        },
      );
      if (response.statusCode != 200) return null;
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) return null;
      final Object? address = decoded['formattedAddress'];
      final Object? location = decoded['location'];
      if (address is! String || location is! Map<String, Object?>) {
        return null;
      }
      final Object? lat = location['latitude'];
      final Object? lng = location['longitude'];
      if (lat is! num || lng is! num) return null;
      return (
        formattedAddress: address,
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  LocationSearchSuggestion? _parseSuggestion(Object? entry) {
    if (entry is! Map<String, Object?>) return null;
    final Object? prediction = entry['placePrediction'];
    if (prediction is! Map<String, Object?>) return null;
    final Object? placeId = prediction['placeId'];
    if (placeId is! String || placeId.isEmpty) return null;
    final Object? structured = prediction['structuredFormat'];
    String primaryText = '';
    String? secondaryText;
    if (structured is Map<String, Object?>) {
      primaryText = _extractText(structured['mainText']) ?? '';
      secondaryText = _extractText(structured['secondaryText']);
    }
    if (primaryText.isEmpty) {
      primaryText = _extractText(prediction['text']) ?? placeId;
    }
    return LocationSearchSuggestion(
      id: placeId,
      primaryText: primaryText,
      secondaryText: secondaryText,
    );
  }

  String? _extractText(Object? node) {
    if (node is Map<String, Object?>) {
      final Object? text = node['text'];
      if (text is String && text.isNotEmpty) return text;
    }
    return null;
  }
}
