import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../shared/primitives/money/currency_code.dart';
import '../../domain/entities/discover_query.dart';
import '../../domain/entities/saved_search_entity.dart';
import '../../domain/entities/smart_search_history_entity.dart';

class DiscoverPreferencesLocalDataSource {
  DiscoverPreferencesLocalDataSource(
    this._secureStorage, {
    required String defaultMarketCityId,
    required double defaultCenterLat,
    required double defaultCenterLng,
    required CurrencyCode defaultCurrency,
  }) : _defaultMarketCityId = defaultMarketCityId,
       _defaultCenterLat = defaultCenterLat,
       _defaultCenterLng = defaultCenterLng,
       _defaultCurrency = defaultCurrency;

  final FlutterSecureStorage _secureStorage;
  final String _defaultMarketCityId;
  final double _defaultCenterLat;
  final double _defaultCenterLng;
  final CurrencyCode _defaultCurrency;
  static const String _lastQueryKey = 'discover.last_query';
  static const String _savedSearchesKey = 'discover.saved_searches';
  static const String _smartSearchHistoryKey = 'discover.smart_search_history';
  static const int _maxSavedSearches = 8;
  static const int _maxSmartSearchHistory = 6;

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
      return DiscoverQuery.fromMap(
        map,
        defaultMarketCityId: _defaultMarketCityId,
        defaultCenterLat: _defaultCenterLat,
        defaultCenterLng: _defaultCenterLng,
        defaultCurrency: _defaultCurrency,
      );
    } on FormatException {
      return null;
    }
  }

  Future<List<SavedSearchEntity>> loadSavedSearches() async {
    final String? raw = await _secureStorage.read(key: _savedSearchesKey);
    if (raw == null || raw.isEmpty) {
      return const <SavedSearchEntity>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) => SavedSearchEntity.fromMap(
              item.map(
                (dynamic key, dynamic value) =>
                    MapEntry<String, Object?>(key as String, value as Object?),
              ),
              defaultMarketCityId: _defaultMarketCityId,
              defaultCenterLat: _defaultCenterLat,
              defaultCenterLng: _defaultCenterLng,
              defaultCurrency: _defaultCurrency,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const <SavedSearchEntity>[];
    } on TypeError {
      return const <SavedSearchEntity>[];
    }
  }

  Future<void> saveSavedSearch(SavedSearchEntity search) async {
    final List<SavedSearchEntity> current = await loadSavedSearches();
    final List<SavedSearchEntity> next = <SavedSearchEntity>[
      search,
      ...current.where((SavedSearchEntity item) => item.id != search.id),
    ].take(_maxSavedSearches).toList(growable: false);
    await _writeSavedSearches(next);
  }

  Future<void> deleteSavedSearch(String id) async {
    final List<SavedSearchEntity> current = await loadSavedSearches();
    final List<SavedSearchEntity> next = current
        .where((SavedSearchEntity item) => item.id != id)
        .toList(growable: false);
    await _writeSavedSearches(next);
  }

  Future<List<SmartSearchHistoryEntity>> loadSmartSearchHistory() async {
    final String? raw = await _secureStorage.read(key: _smartSearchHistoryKey);
    if (raw == null || raw.isEmpty) {
      return const <SmartSearchHistoryEntity>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) => SmartSearchHistoryEntity.fromMap(
              item.map(
                (dynamic key, dynamic value) =>
                    MapEntry<String, Object?>(key as String, value as Object?),
              ),
              defaultMarketCityId: _defaultMarketCityId,
              defaultCenterLat: _defaultCenterLat,
              defaultCenterLng: _defaultCenterLng,
              defaultCurrency: _defaultCurrency,
            ),
          )
          .where(
            (SmartSearchHistoryEntity item) => item.prompt.trim().isNotEmpty,
          )
          .toList(growable: false);
    } on FormatException {
      return const <SmartSearchHistoryEntity>[];
    } on TypeError {
      return const <SmartSearchHistoryEntity>[];
    }
  }

  Future<void> saveSmartSearchPrompt(SmartSearchHistoryEntity item) async {
    final List<SmartSearchHistoryEntity> current =
        await loadSmartSearchHistory();
    final List<SmartSearchHistoryEntity> next = <SmartSearchHistoryEntity>[
      item,
      ...current.where(
        (SmartSearchHistoryEntity currentItem) => currentItem.id != item.id,
      ),
    ].take(_maxSmartSearchHistory).toList(growable: false);
    await _writeSmartSearchHistory(next);
  }

  Future<void> deleteSmartSearchPrompt(String id) async {
    final List<SmartSearchHistoryEntity> current =
        await loadSmartSearchHistory();
    final List<SmartSearchHistoryEntity> next = current
        .where((SmartSearchHistoryEntity item) => item.id != id)
        .toList(growable: false);
    await _writeSmartSearchHistory(next);
  }

  Future<void> _writeSavedSearches(List<SavedSearchEntity> searches) async {
    final String encoded = jsonEncode(
      searches.map((SavedSearchEntity item) => item.toMap()).toList(),
    );
    await _secureStorage.write(key: _savedSearchesKey, value: encoded);
  }

  Future<void> _writeSmartSearchHistory(
    List<SmartSearchHistoryEntity> items,
  ) async {
    final String encoded = jsonEncode(
      items.map((SmartSearchHistoryEntity item) => item.toMap()).toList(),
    );
    await _secureStorage.write(key: _smartSearchHistoryKey, value: encoded);
  }
}
