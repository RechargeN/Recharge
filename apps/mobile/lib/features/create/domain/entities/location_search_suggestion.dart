/// A single autocomplete candidate returned while an author is typing a
/// place/area name during Create (Place identity step, Collection area
/// anchor). Provider-agnostic — carries no Google-specific types so the
/// domain layer never depends on `google_maps_flutter` or a REST payload
/// shape.
class LocationSearchSuggestion {
  const LocationSearchSuggestion({
    required this.id,
    required this.primaryText,
    this.secondaryText,
  });

  /// Opaque provider-side identifier used to resolve full details via
  /// [LocationSearchResolution]. Never persisted — only meaningful for the
  /// lifetime of one search session.
  final String id;

  /// The candidate's name (e.g. a business or landmark name).
  final String primaryText;

  /// Supporting context (e.g. a street/city fragment), when the provider
  /// has one. Not guaranteed.
  final String? secondaryText;
}

/// The resolved details for a chosen [LocationSearchSuggestion] — enough to
/// prefill a draft's location fields, never enough to skip the author's own
/// pin confirmation.
class LocationSearchResolution {
  const LocationSearchResolution({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  final String formattedAddress;
  final double latitude;
  final double longitude;
}
