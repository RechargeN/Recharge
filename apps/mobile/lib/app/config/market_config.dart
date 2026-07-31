class MarketConfig {
  const MarketConfig({
    required this.marketCityId,
    required this.countryCode,
    required this.cityName,
    required this.timezoneId,
    required this.currencyCode,
    required this.defaultLocaleCode,
    required this.supportedLocaleCodes,
    required this.centerLat,
    required this.centerLng,
  });

  final String marketCityId;
  final String countryCode;
  final String cityName;
  final String timezoneId;
  final String currencyCode;
  final String defaultLocaleCode;
  final List<String> supportedLocaleCodes;
  final double centerLat;
  final double centerLng;

  static const MarketConfig riga = MarketConfig(
    marketCityId: 'riga',
    countryCode: 'LV',
    cityName: 'Riga',
    timezoneId: 'Europe/Riga',
    currencyCode: 'EUR',
    defaultLocaleCode: 'en',
    supportedLocaleCodes: <String>['en', 'lv', 'ru'],
    centerLat: 56.9496,
    centerLng: 24.1052,
  );

  static const MarketConfig rezekneLegacy = MarketConfig(
    marketCityId: 'rezekne',
    countryCode: 'LV',
    cityName: 'Rezekne',
    timezoneId: 'Europe/Riga',
    currencyCode: 'EUR',
    defaultLocaleCode: 'en',
    supportedLocaleCodes: <String>['en', 'lv', 'ru'],
    centerLat: 56.5099,
    centerLng: 27.3332,
  );
}

class MarketRegistry {
  const MarketRegistry({
    this.active = MarketConfig.riga,
    this.markets = const <MarketConfig>[
      MarketConfig.riga,
      MarketConfig.rezekneLegacy,
    ],
  });

  final MarketConfig active;
  final List<MarketConfig> markets;

  MarketConfig? byId(String id) {
    for (final MarketConfig market in markets) {
      if (market.marketCityId == id) return market;
    }
    return null;
  }

  MarketConfig? resolveLegacyLocation({
    required String country,
    required String city,
  }) {
    final String normalizedCountry = country.trim().toLowerCase();
    final String normalizedCity = city.trim().toLowerCase();
    if (normalizedCity == 'rezekne' || normalizedCity == 'rēzekne') {
      return byId('rezekne');
    }
    if (normalizedCity == 'riga' || normalizedCity == 'rīga') {
      return byId('riga');
    }
    if ((normalizedCountry == 'latvia' || normalizedCountry == 'lv') &&
        normalizedCity.isEmpty) {
      return active;
    }
    return null;
  }
}
