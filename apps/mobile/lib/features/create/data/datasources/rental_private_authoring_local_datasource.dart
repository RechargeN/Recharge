import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/rental_private_authoring_data.dart';

/// FlutterSecureStorage-backed local store, one entry per draft, keyed
/// independently of the public draft store (mirrors the technology choice
/// of `CreateTemplateLocalDataSource`, not its shared-blob shape — each
/// draft's private data is isolated by key so deleting/rotating one draft
/// never touches another).
class RentalPrivateAuthoringLocalDataSource {
  const RentalPrivateAuthoringLocalDataSource(this._storage);

  final FlutterSecureStorage _storage;

  String _key(String draftId) => 'rental_private_v1_$draftId';

  Future<RentalPrivateAuthoringData> read(String draftId) async {
    try {
      final String? raw = await _storage.read(key: _key(draftId));
      if (raw == null || raw.isEmpty) {
        return const RentalPrivateAuthoringData();
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const RentalPrivateAuthoringData();
      }
      return RentalPrivateAuthoringData.fromMap(decoded);
    } on Object {
      return const RentalPrivateAuthoringData();
    }
  }

  Future<void> write(String draftId, RentalPrivateAuthoringData data) {
    if (data.isEmpty) return _storage.delete(key: _key(draftId));
    return _storage.write(key: _key(draftId), value: jsonEncode(data.toMap()));
  }

  Future<void> delete(String draftId) => _storage.delete(key: _key(draftId));
}
