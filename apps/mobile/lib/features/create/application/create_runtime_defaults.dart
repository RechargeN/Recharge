class CreateRuntimeDefaults {
  const CreateRuntimeDefaults({
    required this.marketCityId,
    required this.timezone,
    required this.country,
    required this.city,
    required this.currency,
    this.defaultContentLocale = 'en',
    this.supportedContentLocales = const <String>{'en', 'ru', 'lv'},
    this.supportedServiceLanguages = const <String>{'en', 'ru', 'lv', 'other'},
    this.marketCenterLat = 0,
    this.marketCenterLng = 0,
  });

  final String marketCityId;
  final String timezone;
  final String country;
  final String city;
  final String currency;
  final String defaultContentLocale;
  final Set<String> supportedContentLocales;
  final Set<String> supportedServiceLanguages;
  final double marketCenterLat;
  final double marketCenterLng;
}
