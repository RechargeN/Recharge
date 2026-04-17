import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/queries/discover_query.dart';

class DiscoverPreferencesLocalDataSource {
  DiscoverPreferencesLocalDataSource(this._secureStorage);

  final FlutterSecureStorage _secureStorage;
  static const String _lastQueryKey = 'discover.last_query';

  Future<void> saveLastQuery(DiscoverQuery query) async {
    final String encoded = jsonEncode(query.toMap());
    await _secureStorage.write(key: _lastQueryKey, value: encoded);
  }

  Future<DiscoverQuery?> loadLastQuery() async {
    final String? raw = await _secureStorage.read(key: _lastQueryKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, Object?> map =
          (jsonDecode(raw) as Map<dynamic, dynamic>).map(
        (dynamic key, dynamic value) =>
            MapEntry<String, Object?>(key as String, value as Object?),
      );
      return DiscoverQuery.fromMap(map);
    } on FormatException {
      return null;
    }
  }
}

