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

  Future<void> saveProfileEditable(
    String userId,
    ProfileEditableModel model,
  ) {
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

  Future<void> saveSettings(
    String userId,
    SettingsModel model,
  ) {
    return _storage.write(
      key: _settingsKey(userId),
      value: jsonEncode(model.toJson()),
    );
  }
}
