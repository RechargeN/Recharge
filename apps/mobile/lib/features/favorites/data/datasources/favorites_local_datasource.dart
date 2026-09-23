import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/favorite_item_model.dart';

class FavoritesLocalDataSource {
  FavoritesLocalDataSource(this._storage, {required String defaultCurrencyCode})
    : _defaultCurrencyCode = defaultCurrencyCode;

  static const String _favoritesKey = 'favorites_items_v1';
  final FlutterSecureStorage _storage;
  final String _defaultCurrencyCode;

  Future<List<FavoriteItemModel>> readFavorites() async {
    final String? raw = await _storage.read(key: _favoritesKey);
    if (raw == null || raw.isEmpty) return const <FavoriteItemModel>[];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => FavoriteItemModel.fromJson(
              item as Map<String, dynamic>,
              defaultCurrencyCode: _defaultCurrencyCode,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const <FavoriteItemModel>[];
    }
  }

  Future<void> writeFavorites(List<FavoriteItemModel> items) {
    final String raw = jsonEncode(
      items
          .map((FavoriteItemModel item) => item.toJson())
          .toList(growable: false),
    );
    return _storage.write(key: _favoritesKey, value: raw);
  }
}
