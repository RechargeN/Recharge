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

  /// The F1 notifications wire locale for a UI language. The server contract
  /// (`notifications_query.schema.json`) names Latvian `lv-LV`; the UI uses the
  /// language-only tag `lv`. Unknown codes return null and are never sent.
  static String? notificationWireLocale(String languageCode) =>
      switch (languageCode) {
        'lv' => 'lv-LV',
        'en' => 'en',
        'ru' => 'ru',
        _ => null,
      };
}
