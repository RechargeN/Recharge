/// Runtime configuration + kill switch for the Place/Collection location
/// search integration (Google Places API New). Nothing in the datasource,
/// coordinators or widgets hardcodes these values.
class LocationSearchRuntimeConfig {
  const LocationSearchRuntimeConfig({
    this.enabled = true,
    this.debounceMilliseconds = 350,
  });

  /// Rollback flag — disabling never removes the manual map-tap fallback,
  /// it only hides the search box/dropdown.
  final bool enabled;

  /// Caller-side (widget) debounce between keystrokes and the search call.
  final int debounceMilliseconds;
}
