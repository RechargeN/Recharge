import 'package:flutter/widgets.dart';

import '../../generated/l10n/app_localizations.dart';

export '../../generated/l10n/app_localizations.dart';

/// L4: the one way UI code reaches localized text.
extension L10nContext on BuildContext {
  /// The app's strings for the current locale. A widget built outside the
  /// app's localization delegates (a bare test harness) gets English, the
  /// deterministic fallback, instead of a crash.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('en'));
}

/// L4: the endonym of a content or UI language tag (`lv` → Latviešu); an
/// unknown tag is shown as the tag itself, never translated.
String languageEndonym(AppLocalizations l10n, String tag) =>
    switch (tag.split(RegExp('[-_]')).first.toLowerCase()) {
      'en' => l10n.languageNameEn,
      'lv' => l10n.languageNameLv,
      'ru' => l10n.languageNameRu,
      _ => tag,
    };
