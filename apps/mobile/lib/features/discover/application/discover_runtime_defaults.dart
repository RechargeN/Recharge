class DiscoverRuntimeDefaults {
  const DiscoverRuntimeDefaults({
    required this.timezoneId,
    required this.originLat,
    required this.originLng,
    required this.currencyCode,
  });

  final String timezoneId;
  final double originLat;
  final double originLng;
  final String currencyCode;
}
