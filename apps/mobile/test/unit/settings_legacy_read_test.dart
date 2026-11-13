import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/explore/data/datasources/explore_local_datasource.dart';
import 'package:recharge/features/explore/data/models/settings_model.dart';

/// L4.9.4: old records with `language` and `currency` still read, those
/// fields get no new value, and a save does not rewrite or clear them.
void main() {
  const FlutterSecureStorage storage = FlutterSecureStorage();

  String keyOf(Map<String, String> all) => all.keys.single;

  test('an old record reads and keeps its old fields through a save', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final ExploreLocalDataSource source = ExploreLocalDataSource(storage);
    await source.saveSettings(
      'u',
      const SettingsModel(notificationsEnabled: true),
    );
    final String key = keyOf(await storage.readAll());
    await storage.write(
      key: key,
      value: jsonEncode(<String, Object?>{
        'language': 'ru',
        'currency': 'USD',
        'notificationsEnabled': true,
      }),
    );

    final SettingsModel? loaded = await source.loadSettings('u');
    expect(loaded?.notificationsEnabled, isTrue);

    await source.saveSettings(
      'u',
      const SettingsModel(notificationsEnabled: false),
    );
    final Map<String, dynamic> stored =
        jsonDecode((await storage.read(key: key))!) as Map<String, dynamic>;
    expect(stored['notificationsEnabled'], isFalse);
    expect(stored['language'], 'ru');
    expect(stored['currency'], 'USD');
  });

  test('a new record never gets the old fields', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final ExploreLocalDataSource source = ExploreLocalDataSource(storage);
    await source.saveSettings(
      'u',
      const SettingsModel(notificationsEnabled: false),
    );
    final Map<String, String> all = await storage.readAll();
    final Map<String, dynamic> stored =
        jsonDecode(all[keyOf(all)]!) as Map<String, dynamic>;
    expect(stored.keys, <String>['notificationsEnabled']);
  });
}
