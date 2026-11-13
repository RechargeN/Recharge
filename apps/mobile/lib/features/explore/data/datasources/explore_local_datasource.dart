import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/profile_editable_model.dart';
import '../models/settings_model.dart';

class ExploreLocalDataSource {
  ExploreLocalDataSource(this._storage);

  final FlutterSecureStorage _storage;

  String _profileKey(String userId) => 'explore_profile_$userId';
  String _settingsKey(String userId) => 'explore_settings_$userId';

  Future<ProfileEditableModel?> loadProfileEditable(String userId) async {
    final String? raw = await _storage.read(key: _profileKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return ProfileEditableModel.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveProfileEditable(String userId, ProfileEditableModel model) {
    return _storage.write(
      key: _profileKey(userId),
      value: jsonEncode(model.toJson()),
    );
  }

  Future<SettingsModel?> loadSettings(String userId) async {
    final String? raw = await _storage.read(key: _settingsKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return SettingsModel.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  /// L4.9.4: writes only the live settings. Whatever else an old record holds
  /// (`language`, `currency`) stays as it was: no value is written to those
  /// fields and nothing is rewritten or cleared behind the user's back.
  Future<void> saveSettings(String userId, SettingsModel model) async {
    final String key = _settingsKey(userId);
    return _storage.write(
      key: key,
      value: jsonEncode(<String, dynamic>{
        ..._storedSettings(await _storage.read(key: key)),
        ...model.toJson(),
      }),
    );
  }

  static Map<String, dynamic> _storedSettings(String? raw) {
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final Object? json = jsonDecode(raw);
      return json is Map<String, dynamic> ? json : const <String, dynamic>{};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }
}
