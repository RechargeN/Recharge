/// L4: which UI language the app shows. A UI language is a presentation
/// preference only: it never selects a market, currency, coordinates or
/// timezone, and it is never inferred from them.
enum AppLocaleChoice {
  /// Follow the device language list, then the market fallback.
  system,
  en,
  lv,
  ru,
}

/// L4 deterministic locale resolution.
///
/// Order: an explicit supported choice; otherwise the first device language
/// whose language subtag is supported (`lv-LV` → `lv`, `ru-RU` → `ru`);
/// otherwise [fallbackLanguageCode]. Unsupported tags (`et`, `lt`, `de`) are
/// skipped, never mapped to a "close" language.
final class AppLocalePolicy {
  AppLocalePolicy({
    required List<String> supportedLanguageCodes,
    required this.fallbackLanguageCode,
  }) : supportedLanguageCodes = List<String>.unmodifiable(
         supportedLanguageCodes,
       ) {
    if (!this.supportedLanguageCodes.contains(fallbackLanguageCode)) {
      throw ArgumentError.value(
        fallbackLanguageCode,
        'fallbackLanguageCode',
        'must be one of the supported language codes',
      );
    }
  }

  /// The R1 UI languages; `lv` is the Latvian language, not the LV market.
  static const List<String> r1LanguageCodes = <String>['en', 'lv', 'ru'];

  /// The R1 API and data identifiers (owner decision 9.1).
  static const List<String> r1CanonicalLocales = <String>['lv-LV', 'en', 'ru'];

  final List<String> supportedLanguageCodes;
  final String fallbackLanguageCode;

  /// The language subtag of [tag] when the app supports it, else null.
  String? supportedLanguageOf(String tag) {
    final String language = tag
        .trim()
        .replaceAll('_', '-')
        .split('-')
        .first
        .toLowerCase();
    return supportedLanguageCodes.contains(language) ? language : null;
  }

  String resolve({
    required AppLocaleChoice choice,
    required List<String> deviceLanguageTags,
  }) {
    if (choice != AppLocaleChoice.system &&
        supportedLanguageCodes.contains(choice.name)) {
      return choice.name;
    }
    for (final String tag in deviceLanguageTags) {
      final String? supported = supportedLanguageOf(tag);
      if (supported != null) return supported;
    }
    return fallbackLanguageCode;
  }

  /// L4.9.1: the API and data identifier of a UI language. `lv-LV`, `en`, `ru`
  /// are canonical; `lv` stays the internal UI and ARB code. This is the one
  /// mapping. An unknown code returns null and is never sent.
  static String? canonicalLocaleOf(String languageCode) =>
      switch (languageCode) {
        'lv' => 'lv-LV',
        'en' => 'en',
        'ru' => 'ru',
        _ => null,
      };

  /// [canonicalLocaleOf] for a tag from saved data: an already canonical or
  /// unknown tag (`other`) passes unchanged.
  static String canonicalTag(String tag) => canonicalLocaleOf(tag) ?? tag;
}
