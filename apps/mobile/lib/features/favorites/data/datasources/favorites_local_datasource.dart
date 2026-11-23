import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/favorite_item_model.dart';

class FavoritesLocalDataSource {
  FavoritesLocalDataSource(this._storage, {this.legacyCurrencyCode})
    : _prefix = 'favorites_items_v2_';

  /// The phone's copy of the server list, shown without a network, under its
  /// own key: it never replaces the list that lives only on this phone. Owner
  /// decision 2026-11-22 ("Оставлять"): a revocation keeps it.
  FavoritesLocalDataSource.savedCopy(this._storage, {this.legacyCurrencyCode})
    : _prefix = 'favorites_saved_copy_v1_';

  final String? legacyCurrencyCode;
  final String _prefix;

  // The legacy global list has no proven owner and is deliberately not adopted.
  String _favoritesKey(String ownerId) {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError('Favorite owner is required');
    }
    return '$_prefix${base64Url.encode(utf8.encode(ownerId))}';
  }

  /// False when nothing was ever written: an empty list is not "no copy".
  Future<bool> hasFavorites(String ownerId) async =>
      await _storage.read(key: _favoritesKey(ownerId)) != null;

  final FlutterSecureStorage _storage;

  Future<List<FavoriteItemModel>> readFavorites(String ownerId) async {
    final String? raw = await _storage.read(key: _favoritesKey(ownerId));
    if (raw == null || raw.isEmpty) return const <FavoriteItemModel>[];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => FavoriteItemModel.fromJson(
              item as Map<String, dynamic>,
              legacyCurrencyCode: legacyCurrencyCode,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      rethrow;
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
