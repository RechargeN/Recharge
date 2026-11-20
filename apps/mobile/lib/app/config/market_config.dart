import '../../shared/primitives/market/market_ref.dart';
import '../../shared/primitives/locale/locale_tag.dart';
import '../../shared/primitives/money/currency_code.dart';
import '../../shared/primitives/time/iana_time_zone.dart';

class MarketConfig {
  factory MarketConfig({
    required MarketRef market,
    required String countryCode,
    required String cityName,
    required IanaTimeZone timezone,
    required CurrencyCode currency,
    required LocaleTag defaultLocale,
    required List<LocaleTag> supportedLocales,
    required double centerLat,
    required double centerLng,
  }) {
    if (!supportedLocales.contains(defaultLocale)) {
      throw ArgumentError('The default locale must be explicitly supported');
    }
    return MarketConfig._(
      market: market,
      countryCode: countryCode,
      cityName: cityName,
      timezone: timezone,
      currency: currency,
      defaultLocale: defaultLocale,
      supportedLocales: List.unmodifiable(supportedLocales),
      centerLat: centerLat,
      centerLng: centerLng,
    );
  }

  const MarketConfig._({
    required this.market,
    required this.countryCode,
    required this.cityName,
    required this.timezone,
    required this.currency,
    required this.defaultLocale,
    required this.supportedLocales,
    required this.centerLat,
    required this.centerLng,
  });

  /// Compatibility adapter: every identity is supplied independently.
  factory MarketConfig.legacy({
    required String marketCityId,
    required String countryCode,
    required String cityName,
    required String timezoneId,
    required String currencyCode,
    required String defaultLocaleCode,
    required List<String> supportedLocaleCodes,
    required double centerLat,
    required double centerLng,
  }) => MarketConfig(
    market: MarketRef.parse(marketCityId),
    countryCode: countryCode,
    cityName: cityName,
    timezone: IanaTimeZone.parse(timezoneId),
    currency: CurrencyCode.parse(currencyCode),
    defaultLocale: LocaleTag.parse(defaultLocaleCode),
    supportedLocales: supportedLocaleCodes.map(LocaleTag.parse).toList(),
    centerLat: centerLat,
    centerLng: centerLng,
  );

  final MarketRef market;
  final String countryCode;
  final String cityName;
  final IanaTimeZone timezone;
  final CurrencyCode currency;
  final LocaleTag defaultLocale;
  final List<LocaleTag> supportedLocales;
  final double centerLat;
  final double centerLng;

  // Compatibility getters remain until M2-D consumer cleanup.
  String get marketCityId => market.value;
  String get timezoneId => timezone.value;
  String get currencyCode => currency.value;
  String get defaultLocaleCode => defaultLocale.value;
  List<String> get supportedLocaleCodes =>
      List.unmodifiable(supportedLocales.map((locale) => locale.value));

  static const MarketConfig riga = MarketConfig._(
    market: MarketRef.riga,
    countryCode: 'LV',
    cityName: 'Riga',
    timezone: IanaTimeZone.europeRiga,
    currency: CurrencyCode.eur,
    defaultLocale: LocaleTag.en,
    supportedLocales: [LocaleTag.en, LocaleTag.lv, LocaleTag.ru],
    centerLat: 56.9496,
    centerLng: 24.1052,
  );
  static const MarketConfig rezekneLegacy = MarketConfig._(
    market: MarketRef.rezekneLegacy,
    countryCode: 'LV',
    cityName: 'Rezekne',
    timezone: IanaTimeZone.europeRiga,
    currency: CurrencyCode.eur,
    defaultLocale: LocaleTag.en,
    supportedLocales: [LocaleTag.en, LocaleTag.lv, LocaleTag.ru],
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

  MarketConfig? byRef(MarketRef ref) => byId(ref.value);

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
