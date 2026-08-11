import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/scenario_object_intake_model.dart';
import '../../domain/entities/scenario_object_intake_session.dart';

class ScenarioObjectIntakeLocalDataSource {
  const ScenarioObjectIntakeLocalDataSource(this._storage);

  static const int _schemaVersion = 1;
  static const int maxSessionsPerOwner = 8;

  final FlutterSecureStorage _storage;

  String _safe(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  String _key(String ownerId) => 'scenario_intake_v1_${_safe(ownerId)}';

  Future<void> put(ScenarioObjectIntakeSession session) async {
    final ownerId = session.intent.requesterId;
    _validateId(ownerId);
    _validateId(session.intent.intentId);
    final sessions = await _readOwner(ownerId);
    sessions.removeWhere(
      (value) => value.intent.intentId == session.intent.intentId,
    );
    sessions.add(session);
    sessions.sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));
    while (sessions.length > maxSessionsPerOwner) {
      sessions.removeAt(0);
    }
    await _writeOwner(ownerId, sessions);
  }

  Future<ScenarioObjectIntakeSession?> load({
    required String ownerId,
    required String intentId,
  }) async {
    _validateId(ownerId);
    _validateId(intentId);
    final sessions = await _readOwner(ownerId);
    for (final session in sessions) {
      if (session.intent.intentId == intentId &&
          session.intent.requesterId == ownerId) {
        return session;
      }
    }
    return null;
  }

  Future<void> replace(ScenarioObjectIntakeSession session) => put(session);

  Future<void> discard({
    required String ownerId,
    required String intentId,
  }) async {
    _validateId(ownerId);
    _validateId(intentId);
    final sessions = await _readOwner(ownerId);
    final before = sessions.length;
    sessions.removeWhere(
      (value) =>
          value.intent.requesterId == ownerId &&
          value.intent.intentId == intentId,
    );
    if (sessions.length != before) await _writeOwner(ownerId, sessions);
  }

  Future<List<ScenarioObjectIntakeSession>> _readOwner(String ownerId) async {
    final raw = await _storage.read(key: _key(ownerId));
    if (raw == null || raw.isEmpty) return <ScenarioObjectIntakeSession>[];
    final json = jsonDecode(raw);
    if (json is! Map ||
        json['schemaVersion'] != _schemaVersion ||
        json['sessions'] is! List) {
      throw const FormatException('Invalid Scenario intake store.');
    }
    final sessions = (json['sessions'] as List)
        .map(
          (value) => ScenarioObjectIntakeSessionModel.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: true);
    if (sessions.any((value) => value.intent.requesterId != ownerId)) {
      throw const FormatException('Scenario intake owner mismatch.');
    }
    return sessions;
  }

  Future<void> _writeOwner(
    String ownerId,
    List<ScenarioObjectIntakeSession> sessions,
  ) => _storage.write(
    key: _key(ownerId),
    value: jsonEncode(<String, Object?>{
      'schemaVersion': _schemaVersion,
      'sessions': sessions
          .map(ScenarioObjectIntakeSessionModel.toJson)
          .toList(growable: false),
    }),
  );

  static void _validateId(String value) {
    final normalized = value.trim();
    if (normalized != value ||
        normalized.isEmpty ||
        normalized.runes.length > 256) {
      throw const FormatException('Invalid Scenario intake storage id.');
    }
  }
}
