import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_locale_policy.dart';
import 'locale_controller.dart';
import 'locale_preference_store.dart';

/// L4: the UI language owner. `main.dart` overrides it with the DI instance
/// (device-scoped secure store); the default is a process-only controller
/// with the R1 policy so an isolated widget still resolves deterministically.
final localeControllerProvider = ChangeNotifierProvider<LocaleController>(
  (ref) => LocaleController(
    policy: AppLocalePolicy(
      supportedLanguageCodes: AppLocalePolicy.r1LanguageCodes,
      fallbackLanguageCode: 'en',
    ),
    store: InMemoryLocalePreferenceStore(),
  ),
);
