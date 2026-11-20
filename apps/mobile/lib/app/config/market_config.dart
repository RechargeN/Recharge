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

  final MarketRef market;
  final String countryCode;
  final String cityName;
  final IanaTimeZone timezone;
  final CurrencyCode currency;
  final LocaleTag defaultLocale;
  final List<LocaleTag> supportedLocales;
  final double centerLat;
  final double centerLng;

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

  MarketConfig? byRef(MarketRef ref) {
    for (final market in markets) {
      if (market.market == ref) return market;
    }
    return null;
  }
}
