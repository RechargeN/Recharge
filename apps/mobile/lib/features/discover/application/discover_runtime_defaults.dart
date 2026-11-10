import '../../../shared/primitives/money/currency_code.dart';

class DiscoverRuntimeDefaults {
  const DiscoverRuntimeDefaults({
    required this.timezoneId,
    required this.currency,
    required this.originLat,
    required this.originLng,
  });

  final String timezoneId;
  final CurrencyCode currency;
  final double originLat;
  final double originLng;
}
