import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/repositories/create_draft_collection_repository.dart';
import '../models/scenario_draft_mapper.dart';

typedef ScenarioInvoke =
    Future<Map<String, Object?>> Function(String, Map<String, Object?>);

class ScenarioSyncFailure implements Exception {
  const ScenarioSyncFailure(this.code);
  final String code;
  @override
  String toString() => 'ScenarioSyncFailure($code)';
}

/// Encrypted account/installation journal. Cache is never server authority.
/// Uses the existing Create conditional-save port; Expand uses the same dispatch.
class ScenarioSyncClient implements CreateDraftCollectionRepository {
  ScenarioSyncClient({
    required ScenarioInvoke invoke,
    required FlutterSecureStorage storage,
    required String installationId,
    required String? Function() currentActor,
    int journalByteLimit = 2 * 1024 * 1024,
  }) : _invoke = invoke,
       _storage = storage,
       _installation = installationId,
       _currentActor = currentActor,
       _journalByteLimit = journalByteLimit;
  final ScenarioInvoke _invoke;
  final FlutterSecureStorage _storage;
  final String _installation;
  final String? Function() _currentActor;
  final int _journalByteLimit;
  Map<String, dynamic> _journal = {};
  String? _actor;
  Future<void> _tail = Future.value();
  final Set<String> _revoked = {};
  final Map<String, int> _revokeEpoch = {};
  final Set<String> _validatedShared = {};
  String _key(String actor) =>
      'scenario_i2_${base64Url.encode(utf8.encode('$_installation:$actor'))}';
  String _check() {
    final actor = _currentActor();
    if (actor == null || (_actor != null && _actor != actor)) {
      clearVisible();
      throw const ScenarioSyncFailure('actor_changed');
    }
    return actor;
  }

  void clearVisible() {
    _actor = null;
    _journal = {};
    _revoked.clear();
    _validatedShared.clear();
  }

  Future<T> _serial<T>(Future<T> Function() f) {
    final result = _tail.then((_) => f());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _load() async {
    final actor = _check();
    final raw = await _storage.read(key: _key(actor));
    if (_currentActor() != actor) {
      clearVisible();
      throw const ScenarioSyncFailure('actor_changed');
    }
    _actor = actor;
    _journal = raw == null
        ? {'cache': {}, 'pending': {}, 'conflicts': {}, 'revoked': []}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    _revoked.addAll((_journal['revoked'] as List? ?? []).cast<String>());
  }

  Future<void> _persist() async {
    final actor = _check();
    _journal['revoked'] = _revoked.toList();
    var encoded = jsonEncode(_journal);
    // Evict only re-fetchable cache. Pending payloads, conflicts and creation
    // receipts must never be discarded to make space for a new intent.
    final cache = _journal['cache'] as Map;
    for (final id in List<String>.from(cache.keys)) {
      if (utf8.encode(encoded).length <= _journalByteLimit) break;
      cache.remove(id);
      _validatedShared.remove(id);
      encoded = jsonEncode(_journal);
    }
    if (utf8.encode(encoded).length > _journalByteLimit) {
      throw const ScenarioSyncFailure('journal_capacity_exceeded');
    }
    await _storage.write(key: _key(actor), value: encoded);
    if (_currentActor() != actor) {
      clearVisible();
      throw const ScenarioSyncFailure('actor_changed');
    }
  }

  Future<void> restore() => _serial(_load);
  Map<String, Object?>? cached(String id) =>
      _actor == _currentActor() &&
          !_revoked.contains(id) &&
          (((_journal['cache'] as Map?)?[id] as Map?)?['role'] == 'owner' ||
              _validatedShared.contains(id))
      ? ((_journal['cache'] as Map?)?[id] is Map
            ? Map<String, Object?>.from((_journal['cache'] as Map)[id] as Map)
            : null)
      : null;
  List<Map<String, Object?>> get conflicts => _actor == _currentActor()
      ? List.unmodifiable(
          ((_journal['conflicts'] as Map?) ?? {}).values
              .where((v) {
                final command = (v as Map)['command'] as Map,
                    id = command['scenarioId'];
                return !_revoked.contains(id) &&
                    (command['generation'] == 0 ||
                        _validatedShared.contains(id));
              })
              .map((v) => Map<String, Object?>.from(v as Map)),
        )
      : const [];

  /// Call synchronously on authoritative revoke event; a late response stays hidden.
  Future<void> receiveRevoke(String id) {
    _revokeEpoch[id] = (_revokeEpoch[id] ?? 0) + 1;
    _revoked.add(id);
    _validatedShared.remove(id);
    (_journal['cache'] as Map?)?.remove(id);
    return _serial(() async {
      await _load();
      _revoked.add(id);
      (_journal['cache'] as Map).remove(id);
      await _persist();
    });
  }

  Future<Map<String, Object?>> read(String id) => _serial(() async {
    await _load();
    final actor = _check();
    final revokeEpoch = _revokeEpoch[id] ?? 0;
    final result = await _invoke('scenarioQueryV1', {
      'schemaVersion': 1,
      'requestId': const Uuid().v4(),
      'scenarioId': id,
    });
    if (_check() != actor) throw const ScenarioSyncFailure('actor_changed');
    if (result['kind'] != 'succeeded') {
      if ([
        'not_found_or_forbidden',
        'access_revoked',
      ].contains(result['code'])) {
        _revoked.add(id);
        (_journal['cache'] as Map).remove(id);
        await _persist();
      }
      throw ScenarioSyncFailure('${result['code']}');
    }
    if ((_revokeEpoch[id] ?? 0) != revokeEpoch) {
      throw const ScenarioSyncFailure('access_revoked');
    }
    _revoked.remove(id);
    _validatedShared.add(id);
    final entry = Map<String, Object?>.from(result['entry'] as Map);
    (_journal['cache'] as Map)[id] = entry;
    await _persist();
    return entry;
  });
  Map<String, Object?> _base(
    String id,
    String type,
    String key,
    int revision,
    int generation,
  ) => {
    'schemaVersion': 1,
    'requestId': const Uuid().v4(),
    'actorContext': _check(),
    'idempotencyKey': key,
    'commandType': type,
    'scenarioId': id,
    'expectedRevision': revision,
    'generation': generation,
  };
  static Map<String, Object?> encode(CreateDraftEntity draft) => {
    'title': draft.title,
    'scenario': ScenarioDraftMapper.toJson(draft.scenarioData!),
  };
  Future<Map<String, Object?>> dispatch(Map<String, Object?> command) =>
      _serial(() async {
        await _load();
        final key = command['idempotencyKey']! as String;
        final pending = _journal['pending'] as Map;
        final old = pending[key];
        Map<String, Object?> withoutRequestId(Map value) =>
            Map<String, Object?>.from(value)..remove('requestId');
        if (old != null &&
            canonical(withoutRequestId(old as Map)) !=
                canonical(withoutRequestId(command))) {
          throw const ScenarioSyncFailure('idempotency_conflict');
        }
        pending[key] = old ?? jsonDecode(jsonEncode(command));
        await _persist();
        return _send(key);
      });
  Future<Map<String, Object?>> _send(String key) async {
    final command = Map<String, Object?>.from(
      (_journal['pending'] as Map)[key] as Map,
    );
    final actor = _check(), id = command['scenarioId']! as String;
    final accepting = command['commandType'] == 'accept';
    final revokeEpoch = _revokeEpoch[id] ?? 0;
    if (command['actorContext'] != actor) {
      throw const ScenarioSyncFailure('actor_changed');
    }
    if (_revoked.contains(id) && !accepting) {
      throw const ScenarioSyncFailure('access_revoked');
    }
    final result = await _invoke('scenarioCommandV1', command);
    if (_check() != actor) throw const ScenarioSyncFailure('actor_changed');
    if ((_revokeEpoch[id] ?? 0) != revokeEpoch ||
        (_revoked.contains(id) && !accepting)) {
      throw const ScenarioSyncFailure('access_revoked');
    }
    if (['unauthenticated', 'feature_disabled'].contains(result['code'])) {
      throw ScenarioSyncFailure('${result['code']}');
    }
    if (!['succeeded', 'rejected'].contains(result['kind'])) {
      throw const ScenarioSyncFailure('invalid_response');
    }
    if (result['kind'] == 'succeeded') {
      if (command['commandType'] == 'expand' && command['replayHash'] == null) {
        final hashed = Map<String, Object?>.from(command)..remove('requestId');
        final compact = Map<String, Object?>.from(command)..remove('draft');
        compact['replayHash'] = sha256
            .convert(utf8.encode(canonical(hashed)))
            .toString();
        (_journal.putIfAbsent('completed', () => {}) as Map)[key] = compact;
      }
      if (accepting) _revoked.remove(id);
      if (result['entry'] is Map) {
        final entry = Map<String, Object?>.from(result['entry'] as Map);
        final current = (_journal['cache'] as Map)[id] as Map?;
        if (current == null ||
            (entry['revision'] as int) >= (current['revision'] as int)) {
          (_journal['cache'] as Map)[id] = entry;
        }
        _validatedShared.add(id);
      }
    } else {
      (_journal['conflicts'] as Map)[key] = {
        'command': command,
        'code': result['code'],
      };
      if ([
        'not_found_or_forbidden',
        'access_revoked',
      ].contains(result['code'])) {
        _revoked.add(id);
        (_journal['cache'] as Map).remove(id);
      }
    }
    (_journal['pending'] as Map).remove(key);
    await _persist();
    return result;
  }

  Future<void> flush() => _serial(() async {
    await _load();
    for (final key in List<String>.from((_journal['pending'] as Map).keys)) {
      final command = (_journal['pending'] as Map)[key] as Map;
      if (_revoked.contains(command['scenarioId'])) continue;
      await _send(key);
    }
  });
  Future<Map<String, Object?>> membership({
    required String scenarioId,
    required String commandType,
    required String intentId,
    required int expectedRevision,
    String? recipientId,
    String? role,
    String? inviteId,
    DateTime? expiresAt,
  }) {
    final command = _base(
      scenarioId,
      commandType,
      intentId,
      expectedRevision,
      0,
    );
    if (recipientId != null) command['recipientId'] = recipientId;
    if (role != null) command['role'] = role;
    if (inviteId != null) command['inviteId'] = inviteId;
    if (expiresAt != null) {
      command['expiresAtUtc'] = expiresAt.toUtc().toIso8601String();
    }
    return dispatch(command);
  }

  /// Persist the fully materialized existing conversion once, before dispatch.
  Future<Map<String, Object?>> expand({
    required String intentId,
    required String sourceId,
    required int sourceRevision,
    required Map<String, Object?> source,
    required Set<String> selectedStopIds,
    required Future<CreateDraftEntity> Function() materialize,
  }) => _serial(() async {
    await _load();
    final pending = _journal['pending'] as Map;
    final sourceHash = sha256
        .convert(utf8.encode(canonical(source)))
        .toString();
    final selection = selectedStopIds.toList()..sort();
    void verifyIntent(Map existing) {
      final oldSelection = List<String>.from(
        existing['selectedStopIds'] as List,
      )..sort();
      if (existing['sourceId'] != sourceId ||
          existing['sourceRevision'] != sourceRevision ||
          existing['sourceHash'] != sourceHash ||
          canonical(oldSelection) != canonical(selection)) {
        throw const ScenarioSyncFailure('idempotency_conflict');
      }
    }

    if (pending.containsKey(intentId)) {
      verifyIntent(pending[intentId] as Map);
      return _send(intentId);
    }
    // Completed intent survives lost response and process restart as a local receipt.
    final completed = (_journal['completed'] as Map?)?[intentId];
    if (completed is Map) {
      verifyIntent(completed);
      final command = Map<String, Object?>.from(completed);
      pending[intentId] = command;
      await _persist();
      return _send(intentId);
    }
    final rejected = (_journal['conflicts'] as Map)[intentId];
    if (rejected is Map) {
      verifyIntent(rejected['command'] as Map);
      throw const ScenarioSyncFailure('intent_rejected');
    }
    final draft = await materialize();
    final command = {
      ..._base(draft.id, 'expand', intentId, 0, 0),
      'draft': encode(draft),
      'sourceId': sourceId,
      'sourceRevision': sourceRevision,
      'sourceHash': sourceHash,
      'selectedStopIds': selectedStopIds.toList(),
    };
    pending[intentId] = jsonDecode(jsonEncode(command));
    await _persist();
    return _send(intentId);
  });
  @override
  Future<CreateDraftCollectionSaveResult> saveIfRevision({
    required String ownerId,
    required CreateDraftEntity draft,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) async {
    if (_check() != ownerId) throw const ScenarioSyncFailure('actor_changed');
    await restore();
    // A persisted generation may queue an offline edit; it never grants a write.
    // Without one, obtain current server access instead of guessing generation 0.
    var entry = (_journal['cache'] as Map)[draft.id] as Map?;
    if (entry == null && expectedScenarioRevision > 0) {
      entry = await read(draft.id);
    }
    final result = await dispatch({
      ..._base(
        draft.id,
        'save',
        idempotencyKey,
        expectedScenarioRevision,
        (entry?['generation'] as int?) ?? 0,
      ),
      'draft': encode(draft),
    });
    return CreateDraftCollectionSaveResult(
      status: result['kind'] == 'succeeded'
          ? CreateDraftCollectionSaveStatus.saved
          : CreateDraftCollectionSaveStatus.conflict,
      persistedRevision: (result['entry'] as Map?)?['revision'] as int?,
    );
  }

  @override
  Future<CreateDraftEntity?> loadDraftById({
    required String ownerId,
    required String draftId,
  }) async {
    if (_check() != ownerId) throw const ScenarioSyncFailure('actor_changed');
    final entry = await read(draftId),
        dto = Map<String, Object?>.from(entry['draft'] as Map);
    return CreateDraftEntity.defaults(
      organizerId: ownerId,
      organizerEmail: '',
      organizerName: '',
    ).copyWith(
      id: draftId,
      objectType: CreateObjectType.scenario,
      title: dto['title']! as String,
      scenarioData: ScenarioDraftMapper.fromJson(
        Map<String, Object?>.from(dto['scenario'] as Map),
      ),
    );
  }

  @override
  Future<List<CreateDraftSummary>> listDrafts({
    required String ownerId,
    required CreateObjectType type,
  }) async {
    if (_check() != ownerId) throw const ScenarioSyncFailure('actor_changed');
    if (type != CreateObjectType.scenario) return const [];
    final entries = <Map>[];
    Object? cursor;
    do {
      final result = await _invoke('scenarioQueryV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        if (cursor != null) 'cursor': cursor,
      });
      if (_check() != ownerId) throw const ScenarioSyncFailure('actor_changed');
      if (result['kind'] != 'succeeded') {
        throw ScenarioSyncFailure('${result['code']}');
      }
      entries.addAll((result['entries'] as List).cast<Map>());
      final next = result['cursor'];
      if (result['hasMore'] == true &&
          (next == null || canonical(cursor) == canonical(next))) {
        throw const ScenarioSyncFailure('invalid_response');
      }
      cursor = next;
    } while (cursor != null);
    return entries
        .cast<Map>()
        .where((e) => !_revoked.contains(e['scenarioId']))
        .map(
          (e) => CreateDraftSummary(
            id: e['scenarioId'] as String,
            objectType: CreateObjectType.scenario,
            title: e['title'] as String,
            updatedAtUtc: DateTime.parse(e['updatedAtUtc'] as String),
            scenarioRevision: e['revision'] as int,
          ),
        )
        .toList();
  }

  static String canonical(Object? value) {
    return ScenarioDraftMapper.canonicalJson(value);
  }
}
