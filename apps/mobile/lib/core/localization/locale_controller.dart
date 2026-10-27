import 'package:flutter/foundation.dart';

import 'app_locale_policy.dart';
import 'locale_preference_store.dart';

/// L4: the single owner of the UI language. It resolves the language from the
/// stored choice and the device language list and persists explicit choices.
/// Nothing else in the app reads the device locale for UI text.
final class LocaleController extends ChangeNotifier {
  LocaleController({
    required AppLocalePolicy policy,
    required LocalePreferenceStore store,
    List<String> deviceLanguageTags = const <String>[],
  }) : _policy = policy,
       _store = store,
       _deviceLanguageTags = List<String>.unmodifiable(deviceLanguageTags);

  final AppLocalePolicy _policy;
  final LocalePreferenceStore _store;
  List<String> _deviceLanguageTags;
  AppLocaleChoice _choice = AppLocaleChoice.system;

  AppLocaleChoice get choice => _choice;
  AppLocalePolicy get policy => _policy;

  /// The resolved UI language code (`en`, `lv` or `ru`).
  String get languageCode =>
      _policy.resolve(choice: _choice, deviceLanguageTags: _deviceLanguageTags);

  /// The notifications wire locale for the current UI language.
  String get notificationWireLocale =>
      AppLocalePolicy.notificationWireLocale(languageCode) ??
      AppLocalePolicy.notificationWireLocale(_policy.fallbackLanguageCode)!;

  /// Restores the stored choice (app start).
  Future<void> load() async {
    final AppLocaleChoice? stored = await _store.read();
    final AppLocaleChoice next = stored ?? AppLocaleChoice.system;
    if (next == _choice) return;
    _choice = next;
    notifyListeners();
  }

  /// Persists an explicit choice; `system` returns to the device language.
  Future<void> select(AppLocaleChoice choice) async {
    await _store.write(choice);
    if (choice == _choice) return;
    _choice = choice;
    notifyListeners();
  }

  /// The device language list changed (system settings).
  void updateDeviceLanguages(List<String> tags) {
    final String before = languageCode;
    _deviceLanguageTags = List<String>.unmodifiable(tags);
    if (languageCode != before) notifyListeners();
  }
}
