import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/visited_place_model.dart';

class VisitedPlacesLocalDataSource {
  VisitedPlacesLocalDataSource(this._storage);

  static const String keyPrefix = 'visit_history_v2_';
  final FlutterSecureStorage _storage;

  Future<List<VisitedPlaceModel>> readVisitedPlaces(String userId) async {
    final String? raw = await _storage.read(key: _storageKey(userId));
    if (raw == null || raw.isEmpty) return const <VisitedPlaceModel>[];

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<VisitedPlaceModel> result = <VisitedPlaceModel>[];
      for (final dynamic item in decoded) {
        try {
          final model = VisitedPlaceModel.fromJson(
            item as Map<String, dynamic>,
          );
          model.toEntity();
          result.add(model);
        } on Object {
          // A corrupt or future record is ignored without hiding valid records.
        }
      }
      return result;
    } on Object {
      return const <VisitedPlaceModel>[];
    }
  }

  Future<void> writeVisitedPlaces(
    String userId,
    List<VisitedPlaceModel> items,
  ) {
    final String raw = jsonEncode(
      items
          .map((VisitedPlaceModel item) => item.toJson())
          .toList(growable: false),
    );
    return _storage.write(key: _storageKey(userId), value: raw);
  }

  String _storageKey(String userId) {
    final String safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '$keyPrefix$safeUserId';
  }
}
