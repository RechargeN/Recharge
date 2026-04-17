import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session_model.dart';
import '../models/auth_user_model.dart';

class AuthLocalDataSource {
  const AuthLocalDataSource(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  static const String _sessionKey = 'auth.session';
  static const String _userKey = 'auth.user';

  Future<void> saveSession(AuthSessionModel session) {
    return _secureStorage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<AuthSessionModel?> readSession() async {
    final raw = await _secureStorage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AuthSessionModel.fromJson(json);
  }

  Future<void> saveUser(AuthUserModel user) {
    return _secureStorage.write(
      key: _userKey,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<AuthUserModel?> readUser() async {
    final raw = await _secureStorage.read(key: _userKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AuthUserModel.fromJson(json);
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _sessionKey);
    await _secureStorage.delete(key: _userKey);
  }
}
