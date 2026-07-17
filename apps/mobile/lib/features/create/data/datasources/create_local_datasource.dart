import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/create_draft_model.dart';

class CreateLocalDataSource {
  CreateLocalDataSource(
    this._storage, {
    this.activeMarketCityId = '',
    this.activeTimezone = 'UTC',
    this.activeCountry = '',
    this.activeCity = '',
  });

  final FlutterSecureStorage _storage;
  final String activeMarketCityId;
  final String activeTimezone;
  final String activeCountry;
  final String activeCity;

  String _draftKey(String userId) => 'create_draft_$userId';

  Future<CreateDraftModel?> loadDraft(String userId) async {
    final String? raw = await _storage.read(key: _draftKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return CreateDraftModel.fromJson(
        json,
        activeMarketCityId: activeMarketCityId,
        activeTimezone: activeTimezone,
        activeCountry: activeCountry,
        activeCity: activeCity,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> saveDraft(String userId, CreateDraftModel model) {
    return _storage.write(
      key: _draftKey(userId),
      value: jsonEncode(model.toJson()),
    );
  }
}
