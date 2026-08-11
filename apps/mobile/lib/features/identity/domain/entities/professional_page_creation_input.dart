import 'managed_page_entity.dart';

class ProfessionalPageCreationInput {
  const ProfessionalPageCreationInput({
    required this.kind,
    required this.displayName,
    required this.marketId,
    required this.countryCode,
    required this.defaultLocale,
    required this.timezone,
    required this.defaultCurrency,
    required this.supportedLocales,
  });

  final ManagedPageKind kind;
  final String displayName;
  final String marketId;
  final String countryCode;
  final String defaultLocale;
  final String timezone;
  final String defaultCurrency;
  final List<String> supportedLocales;
}
