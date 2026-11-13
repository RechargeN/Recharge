import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/favorite_item_model.dart';

class FavoritesLocalDataSource {
  FavoritesLocalDataSource(this._storage, {required String defaultCurrencyCode})
    : _defaultCurrencyCode = defaultCurrencyCode;

  // The legacy global list has no proven owner and is deliberately not adopted.
  static String _favoritesKey(String ownerId) {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError('Favorite owner is required');
    }
    return 'favorites_items_v2_${base64Url.encode(utf8.encode(ownerId))}';
  }

  final FlutterSecureStorage _storage;
  final String _defaultCurrencyCode;

  Future<List<FavoriteItemModel>> readFavorites(String ownerId) async {
    final String? raw = await _storage.read(key: _favoritesKey(ownerId));
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

  Future<void> writeFavorites(String ownerId, List<FavoriteItemModel> items) {
    final String raw = jsonEncode(
      items
          .map((FavoriteItemModel item) => item.toJson())
          .toList(growable: false),
    );
    return _storage.write(key: _favoritesKey(ownerId), value: raw);
  }
}
