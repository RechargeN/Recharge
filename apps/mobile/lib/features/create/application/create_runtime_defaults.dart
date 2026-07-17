class CreateRuntimeDefaults {
  const CreateRuntimeDefaults({
    required this.marketCityId,
    required this.timezone,
    required this.country,
    required this.city,
    required this.currency,
  });

  final String marketCityId;
  final String timezone;
  final String country;
  final String city;
  final String currency;
}
