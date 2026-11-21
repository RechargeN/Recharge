import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/offline_account_store.dart';
import '../models/auth_session_model.dart';
import '../models/auth_user_model.dart';

class AuthLocalDataSource implements OfflineAccountStore {
  const AuthLocalDataSource(
    this._secureStorage, {
    this.environment = AuthCacheEnvironment.local,
  });

  final AuthCacheEnvironment environment;

  final FlutterSecureStorage _secureStorage;

  String get _sessionKey => '${environment.namespace}.session';
  String get _userKey => '${environment.namespace}.user';

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

  String get _offlineProfileKey => '${environment.namespace}.offlineProfile';

  @override
  Future<void> saveOfflineProfile(AuthUserEntity user) {
    return _secureStorage.write(
      key: _offlineProfileKey,
      value: jsonEncode(<String, String>{'id': user.id, 'email': user.email}),
    );
  }

  @override
  Future<AuthUserEntity?> readOfflineProfile() async {
    try {
      final raw = await _secureStorage.read(key: _offlineProfileKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final id = json['id'];
      final email = json['email'];
      if (id is! String || id.isEmpty || email is! String) return null;
      return AuthUserEntity(
        id: id,
        email: email,
        role: '',
        capabilities: const <String>[],
        profileStatus: 'offline',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearOfflineProfile() =>
      _secureStorage.delete(key: _offlineProfileKey);

  @override
  Future<void> wipeAccountData(String userId) async {
    if (userId.isEmpty) return;
    // Personal stores key their records by the account id: raw, sanitized
    // (visits) or base64url (Create collections).
    final forms = <String>{
      userId,
      userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'),
      base64Url.encode(utf8.encode(userId)).replaceAll('=', ''),
    };
    final all = await _secureStorage.readAll();
    for (final key in all.keys) {
      if (forms.any(key.contains)) await _secureStorage.delete(key: key);
    }
    await clearOfflineProfile();
  }
}

/// Persisted authority must never cross Local, Emulator, and dev boundaries.
enum AuthCacheEnvironment {
  local('auth'),
  emulator('auth.emulator.demo-recharge'),
  dev('auth.dev.recharge-dev-n2a01'),
  // N4b (2026-11-13): staging never shares persisted authority with dev.
  staging('auth.staging.recharge-staging-y9y2y');

  const AuthCacheEnvironment(this.namespace);
  final String namespace;
}
