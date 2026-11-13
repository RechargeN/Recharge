import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_locale_policy.dart';

/// L4: where the UI language choice lives. The choice belongs to the device
/// installation, not to an account: it applies before sign-in, survives
/// logout, and the next account on the same device sees the same language
/// until it is changed. There is no server-side account language in R1.
abstract interface class LocalePreferenceStore {
  /// The stored choice, or null when nothing (or an unknown value) is stored.
  Future<AppLocaleChoice?> read();
  Future<void> write(AppLocaleChoice choice);
}

final class SecureLocalePreferenceStore implements LocalePreferenceStore {
  SecureLocalePreferenceStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String storageKey = 'app.locale_preference.v1';

  @override
  Future<AppLocaleChoice?> read() async {
    final String? raw = await _storage.read(key: storageKey);
    for (final AppLocaleChoice choice in AppLocaleChoice.values) {
      if (choice.name == raw) return choice;
    }
    // An unknown or future value is ignored, not rewritten: a newer app
    // version may still read it.
    return null;
  }

  @override
  Future<void> write(AppLocaleChoice choice) =>
      _storage.write(key: storageKey, value: choice.name);
}

/// Process-only store for tests and previews.
final class InMemoryLocalePreferenceStore implements LocalePreferenceStore {
  InMemoryLocalePreferenceStore([this._value]);

  AppLocaleChoice? _value;

  @override
  Future<AppLocaleChoice?> read() async => _value;

  @override
  Future<void> write(AppLocaleChoice choice) async => _value = choice;
}
