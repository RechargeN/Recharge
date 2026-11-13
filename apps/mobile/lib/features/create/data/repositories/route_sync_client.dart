import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/id/id_generator.dart';
import '../../domain/entities/route_draft_data.dart';
import '../../domain/entities/route_sync_data.dart';
import '../../domain/repositories/route_gpx_repository.dart';
import '../../domain/repositories/route_sync_repository.dart';
import '../../domain/usecases/apply_route_edit_command_usecase.dart';
import '../models/route_canonical_codec.dart';

typedef RouteInvoke =
    Future<Map<String, Object?>> Function(String, Map<String, Object?>);

/// J1 owner Route sync over `routeCommandV1`/`routeQueryV1`. One encrypted
/// journal per installation and owner holds the ordered queue, refused
/// commands, the local→permanent ID map and a re-fetchable cache.
class RouteSyncClient implements RouteSyncRepository {
  RouteSyncClient({
    required RouteInvoke invoke,
    required FlutterSecureStorage storage,
    required String installationId,
    required String? Function() currentOwner,
    IdGenerator? ids,
    int journalByteLimit = 2 * 1024 * 1024,
  }) : _invoke = invoke,
       _storage = storage,
       _installation = installationId,
       _currentOwner = currentOwner,
       _ids = ids ?? UlidIdGenerator(),
       _journalByteLimit = journalByteLimit;

  static const Set<String> _terminal = <String>{
    'revision_conflict',
    'deleted',
    'id_collision',
    'idempotency_conflict',
    'request_invalid',
    'not_found',
    'payload_too_large',
    'point_limit_exceeded',
    'invalid_geometry',
    'license_blocked',
    'provenance_unverified',
    'privacy_trim_invalid',
    'privacy_trim_empty',
  };

  final RouteInvoke _invoke;
  final FlutterSecureStorage _storage;
  final String _installation;
  final String? Function() _currentOwner;
  final IdGenerator _ids;
  final int _journalByteLimit;
  Future<void> _tail = Future<void>.value();
  Map<String, dynamic> _journal = <String, dynamic>{};
  String? _visibleOwner;

  String _key(String owner) =>
      'route_j1_${base64Url.encode(utf8.encode('$_installation:$owner'))}';

  String _owner() {
    final owner = _currentOwner();
    if (owner == null) {
      clearVisible();
      throw const RouteSyncFailure('unauthenticated');
    }
    return owner;
  }

  void _check(String owner) {
    if (_currentOwner() != owner) {
      clearVisible();
      throw const RouteSyncFailure('owner_changed');
    }
  }

  @override
  void clearVisible() {
    _journal = <String, dynamic>{};
    _visibleOwner = null;
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _load(String owner) async {
    _check(owner);
    final raw = await _storage.read(key: _key(owner));
    _check(owner);
    _journal = raw == null
        ? <String, dynamic>{
            'pending': <Object?>[],
            'conflicts': <Object?>[],
            'cache': <String, Object?>{},
            'ids': <String, Object?>{},
          }
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    _visibleOwner = owner;
  }

  Future<void> _persist(String owner) async {
    _check(owner);
    var encoded = jsonEncode(_journal);
    // Only the re-fetchable cache may be evicted; queue, refusals and the ID
    // map are never dropped to make room.
    final cache = _journal['cache'] as Map;
    for (final id in List<String>.from(cache.keys)) {
      if (utf8.encode(encoded).length <= _journalByteLimit) break;
      cache.remove(id);
      encoded = jsonEncode(_journal);
    }
    if (utf8.encode(encoded).length > _journalByteLimit) {
      throw const RouteSyncFailure('journal_capacity_exceeded');
    }
    await _storage.write(key: _key(owner), value: encoded);
    _check(owner);
  }

  List<dynamic> get _pending => _journal['pending'] as List;
  List<dynamic> get _refused => _journal['conflicts'] as List;
  Map<dynamic, dynamic> get _cache => _journal['cache'] as Map;
  Map<dynamic, dynamic> get _idMap => _journal['ids'] as Map;

  @override
  Future<void> restore() => _serial(() async {
    final owner = _currentOwner();
    if (owner == null) {
      clearVisible();
      return;
    }
    await _load(owner);
  });

  static String _hash(Object? value) => sha256
      .convert(utf8.encode(RouteCanonicalCodec.canonicalJson(value)))
      .toString()
      .substring(0, 40);

  /// Encodes [route] with permanent IDs that are created once per local ID
  /// and reused on every later save. Mappings of local IDs the draft no longer
  /// uses are dropped, so the journal does not grow with editing history;
  /// queued and refused commands already carry their encoded payloads.
  (String, Map<String, Object?>) _encodeFor(
    String localDraftId,
    RouteDraftData route,
    String title,
  ) {
    final entry =
        _idMap.putIfAbsent(
              localDraftId,
              () => <String, Object?>{
                'routeId': RouteCanonicalCodec.isEntityId(localDraftId)
                    ? localDraftId
                    : _ids.generate(),
                'nested': <String, Object?>{},
              },
            )
            as Map;
    final nested = entry['nested'] as Map;
    final used = <String>{};
    final Map<String, Object?> dto;
    try {
      dto = RouteCanonicalCodec.encode(
        route,
        title: title,
        idFor: (String local) {
          used.add(local);
          return nested.putIfAbsent(local, _ids.generate) as String;
        },
      );
    } on RouteCanonicalFailure catch (error) {
      throw RouteSyncFailure(error.code);
    }
    nested.removeWhere((key, _) => !used.contains(key));
    return (entry['routeId']! as String, dto);
  }

  Map<String, Object?> _command(
    String owner,
    String type,
    String routeId,
    int expectedRevision,
    Map<String, Object?> body,
  ) {
    final intent = <String, Object?>{
      'commandType': type,
      'routeId': routeId,
      'expectedRevision': expectedRevision,
      ...body,
    };
    return <String, Object?>{
      'schemaVersion': 1,
      'ownerContext': owner,
      'idempotencyKey': '$type-${_hash(intent)}',
      ...intent,
    };
  }

  Future<RouteSyncEntry?> _enqueue(
    String owner,
    Map<String, Object?> command,
  ) async {
    final key = command['idempotencyKey']! as String;
    final existing = _pending.cast<Map>().where((p) => p['key'] == key);
    if (existing.isNotEmpty &&
        _hash(existing.first['command']) != _hash(command)) {
      throw const RouteSyncFailure('idempotency_conflict');
    }
    if (existing.isEmpty) {
      _pending.add(<String, Object?>{
        'key': key,
        'command': jsonDecode(jsonEncode(command)),
      });
    }
    // Durable before dispatch: a crash or lost answer replays the same intent.
    await _persist(owner);
    await _drain(owner);
    return cached(command['routeId']! as String);
  }

  @override
  Future<RouteSyncEntry?> importRoute({
    required String localDraftId,
    required String title,
    required RouteDraftData route,
  }) {
    final owner = _owner();
    return _serial(() async {
      await _load(owner);
      final imported = route.segments
          .where((s) => s.source == RouteSegmentSource.importedGpx)
          .map((s) => s.provenance.sourceId)
          .toSet();
      if (route.creationMethod != RouteCreationMethod.importedGpx ||
          imported.length != 1) {
        throw const RouteSyncFailure('provenance_unverified');
      }
      final (routeId, dto) = _encodeFor(localDraftId, route, title);
      final duplicates = route.sourceIssues
          .where((issue) => issue.code == 'gpx_duplicates_removed')
          .fold<num>(
            0,
            (sum, issue) => sum + (issue.safeMetrics['count'] ?? 0),
          );
      final bridges = route.segments
          .where((s) => s.source == RouteSegmentSource.intentionalDirect)
          .length;
      final command = _command(owner, 'import', routeId, 0, <String, Object?>{
        'route': dto,
        'importSource': <String, Object?>{
          'sourceId': imported.single,
          'parserVersion': RouteGpxImportResult.parserVersion,
          'transformations': <Object?>[
            <String, Object?>{'code': 'strip-timestamps', 'count': null},
            <String, Object?>{'code': 'strip-metadata', 'count': null},
            <String, Object?>{'code': 'quantize-e7-dm', 'count': null},
            <String, Object?>{
              'code': 'drop-consecutive-duplicates',
              'count': duplicates.toInt(),
            },
            <String, Object?>{'code': 'direct-gap-bridge', 'count': bridges},
          ],
        },
      });
      // One import intent per local draft: a changed re-import is refused.
      command['idempotencyKey'] = 'import-${_hash(<String>[routeId])}';
      return _enqueue(owner, command);
    });
  }

  @override
  Future<RouteSyncEntry?> save({
    required String localDraftId,
    required String title,
    required RouteDraftData route,
    required int expectedRevision,
  }) {
    final owner = _owner();
    return _serial(() async {
      await _load(owner);
      final (routeId, dto) = _encodeFor(localDraftId, route, title);
      return _enqueue(
        owner,
        _command(owner, 'save', routeId, expectedRevision, <String, Object?>{
          'route': dto,
        }),
      );
    });
  }

  @override
  Future<RouteSyncEntry?> setPrivacyTrim({
    required String routeId,
    required RoutePrivacyTrim trim,
    required int expectedRevision,
  }) {
    if (!trim.isValid) {
      return Future<RouteSyncEntry?>.error(
        const RouteSyncFailure('privacy_trim_invalid'),
      );
    }
    final owner = _owner();
    return _serial(() async {
      await _load(owner);
      return _enqueue(
        owner,
        _command(
          owner,
          'setPrivacyTrim',
          routeId,
          expectedRevision,
          <String, Object?>{
            'privacyTrim': <String, Object?>{
              'startMeters': trim.startMeters,
              'endMeters': trim.endMeters,
            },
          },
        ),
      );
    });
  }

  @override
  Future<RouteSyncEntry?> delete({
    required String routeId,
    required int expectedRevision,
  }) {
    final owner = _owner();
    return _serial(() async {
      await _load(owner);
      return _enqueue(
        owner,
        _command(
          owner,
          'delete',
          routeId,
          expectedRevision,
          const <String, Object?>{},
        ),
      );
    });
  }

  @override
  Future<void> flush() {
    final owner = _owner();
    return _serial(() async {
      await _load(owner);
      await _drain(owner);
    });
  }

  Future<Map<String, Object?>> _query(
    String owner,
    Map<String, Object?> request,
  ) async {
    _check(owner);
    final Map<String, Object?> answer;
    try {
      answer = await _invoke('routeQueryV1', <String, Object?>{
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        ...request,
      });
    } on RouteSyncFailure {
      rethrow;
    } on Object {
      throw const RouteSyncFailure('transport_unavailable');
    }
    _check(owner);
    if (answer['kind'] != 'succeeded') {
      throw RouteSyncFailure(answer['code'] as String? ?? 'answer_invalid');
    }
    if (answer.containsKey('ownerId') && answer['ownerId'] != owner) {
      clearVisible();
      throw const RouteSyncFailure('owner_changed');
    }
    return answer;
  }

  Future<void> _refreshEntry(String owner, String routeId) async {
    final answer = await _query(owner, <String, Object?>{
      'queryType': 'get',
      'routeId': routeId,
    });
    final entry = answer['entry'];
    if (entry == null) {
      _cache.remove(routeId);
    } else {
      _decodeEntry(Map<String, Object?>.from(entry as Map));
      _cache[routeId] = entry;
    }
  }

  Future<void> _drain(String owner) async {
    RouteSyncFailure? refused;
    while (_pending.isNotEmpty) {
      _check(owner);
      final item = Map<String, Object?>.from(_pending.first as Map);
      final command = Map<String, Object?>.from(item['command']! as Map);
      final routeId = command['routeId']! as String;
      if (command['ownerContext'] != owner) {
        throw const RouteSyncFailure('owner_changed');
      }
      // No command is dispatched under an unverified or different session.
      await _query(owner, <String, Object?>{
        'queryType': 'get',
        'routeId': routeId,
      });
      final Map<String, Object?> answer;
      try {
        answer = await _invoke('routeCommandV1', <String, Object?>{
          ...command,
          'requestId': const Uuid().v4(),
        });
      } on RouteSyncFailure {
        rethrow;
      } on Object {
        // Unknown outcome: the intent stays queued and is replayed later.
        throw const RouteSyncFailure('transport_unavailable');
      }
      _check(owner);
      final code = answer['code'] as String?;
      if (answer['kind'] == 'rejected' && !_terminal.contains(code)) {
        throw RouteSyncFailure(code ?? 'answer_invalid');
      }
      if (answer['kind'] != 'succeeded' && answer['kind'] != 'rejected') {
        throw const RouteSyncFailure('answer_invalid');
      }
      if (answer['kind'] == 'rejected') {
        _refused.add(<String, Object?>{
          'key': item['key'],
          'command': command,
          'code': code,
          'serverRevision': answer['serverRevision'],
        });
        refused ??= RouteSyncFailure(code!);
      }
      // Historical receipts never update the cache: read current state.
      await _refreshEntry(owner, routeId);
      _pending.removeAt(0);
      await _persist(owner);
    }
    if (refused != null) throw refused;
  }

  @override
  Future<RouteSyncEntry?> refresh(String routeId) {
    final owner = _owner();
    return _serial(() async {
      await _load(owner);
      await _drain(owner);
      await _refreshEntry(owner, routeId);
      await _persist(owner);
      return cached(routeId);
    });
  }

  @override
  Future<List<RouteSyncEntry>> list() {
    final owner = _owner();
    return _serial(() async {
      await _load(owner);
      final entries = <RouteSyncEntry>[];
      String? cursor;
      for (var page = 0; page < 200; page++) {
        final answer = await _query(owner, <String, Object?>{
          'queryType': 'list',
          'cursor': cursor,
        });
        for (final raw in (answer['entries']! as List).cast<Map>()) {
          entries.add(
            RouteSyncEntry(
              routeId: raw['routeId']! as String,
              revision: raw['revision']! as int,
              deleted: raw['status'] == 'deleted',
              title: raw['title'] as String? ?? '',
              updatedAtUtc: DateTime.parse(raw['updatedAtUtc']! as String),
            ),
          );
        }
        final next = answer['cursor'] as String?;
        if (answer['hasMore'] != true) return entries;
        if (next == null || next == cursor) {
          throw const RouteSyncFailure('answer_invalid');
        }
        cursor = next;
      }
      throw const RouteSyncFailure('answer_invalid');
    });
  }

  @override
  Future<RouteTrimmedView> trimmedView(
    String routeId, {
    required int expectedRevision,
  }) {
    final owner = _owner();
    return _serial(() async {
      final answer = await _query(owner, <String, Object?>{
        'queryType': 'trimmedView',
        'routeId': routeId,
        'expectedRevision': expectedRevision,
      });
      try {
        final view = RouteCanonicalCodec.trimmedView(
          Map<String, Object?>.from(answer['view']! as Map),
        );
        if (view.routeId != routeId || view.revision != expectedRevision) {
          throw const RouteSyncFailure('answer_invalid');
        }
        return view;
      } on RouteCanonicalFailure catch (error) {
        throw RouteSyncFailure(error.code);
      }
    });
  }

  RouteSyncEntry _decodeEntry(Map<String, Object?> raw) {
    try {
      final deleted = raw['status'] == 'deleted';
      if (!deleted && raw['status'] != 'active') {
        throw const RouteSyncFailure('answer_invalid');
      }
      final route = raw['route'] as Map?;
      final trim = raw['privacyTrim'] as Map?;
      return RouteSyncEntry(
        routeId: raw['routeId']! as String,
        revision: raw['revision']! as int,
        deleted: deleted,
        title: route?['title'] as String? ?? '',
        updatedAtUtc: DateTime.parse(raw['updatedAtUtc']! as String),
        route: route == null ? null : Map<String, Object?>.from(route),
        privacyTrim: trim == null
            ? null
            : RoutePrivacyTrim(
                startMeters: trim['startMeters']! as int,
                endMeters: trim['endMeters']! as int,
              ),
        origin: (raw['provenance'] as Map?)?['origin'] as String?,
        summary: raw['summary'] == null
            ? null
            : RouteCanonicalCodec.summary(
                Map<String, Object?>.from(raw['summary']! as Map),
              ),
      );
    } on RouteSyncFailure {
      rethrow;
    } on Object {
      throw const RouteSyncFailure('answer_invalid');
    }
  }

  @override
  RouteSyncEntry? cached(String routeId) {
    if (_visibleOwner == null || _visibleOwner != _currentOwner()) return null;
    final raw = _cache[routeId];
    if (raw is! Map) return null;
    final entry = _decodeEntry(Map<String, Object?>.from(raw));
    return entry.deleted ? null : entry;
  }

  /// The tombstone stays visible to callers that need to stop editing.
  RouteSyncEntry? cachedIncludingDeleted(String routeId) {
    if (_visibleOwner == null || _visibleOwner != _currentOwner()) return null;
    final raw = _cache[routeId];
    return raw is Map ? _decodeEntry(Map<String, Object?>.from(raw)) : null;
  }

  @override
  String? routeIdFor(String localDraftId) {
    if (_visibleOwner == null || _visibleOwner != _currentOwner()) return null;
    return (_idMap[localDraftId] as Map?)?['routeId'] as String?;
  }

  @override
  bool hasPending(String routeId) =>
      _visibleOwner != null &&
      _visibleOwner == _currentOwner() &&
      _pending.cast<Map>().any(
        (p) => (p['command'] as Map)['routeId'] == routeId,
      );

  @override
  List<RouteSyncConflict> get conflicts {
    if (_visibleOwner == null || _visibleOwner != _currentOwner()) {
      return const <RouteSyncConflict>[];
    }
    return List<RouteSyncConflict>.unmodifiable(
      _refused.cast<Map>().map(
        (c) => RouteSyncConflict(
          key: c['key']! as String,
          routeId: (c['command'] as Map)['routeId']! as String,
          commandType: (c['command'] as Map)['commandType']! as String,
          code: c['code']! as String,
          serverRevision: c['serverRevision'] as int?,
        ),
      ),
    );
  }

  /// The refused payload of a conflict, for the author's side-by-side review.
  Map<String, Object?>? conflictPayload(String key) {
    if (_visibleOwner == null || _visibleOwner != _currentOwner()) return null;
    for (final c in _refused.cast<Map>()) {
      if (c['key'] == key) {
        return Map<String, Object?>.from(c['command'] as Map);
      }
    }
    return null;
  }

  @override
  Future<void> resolveConflict(String key, {required bool reapplyLocal}) {
    final owner = _owner();
    return _serial(() async {
      await _load(owner);
      final index = _refused.indexWhere((c) => (c as Map)['key'] == key);
      if (index < 0) throw const RouteSyncFailure('not_found');
      final command = Map<String, Object?>.from(
        (_refused[index] as Map)['command']! as Map,
      );
      if (!reapplyLocal) {
        _refused.removeAt(index);
        await _persist(owner);
        return;
      }
      if (command['commandType'] == 'import') {
        throw const RouteSyncFailure('import_not_reappliable');
      }
      final routeId = command['routeId']! as String;
      await _refreshEntry(owner, routeId);
      final current = cachedIncludingDeleted(routeId);
      if (current == null || current.deleted) {
        throw const RouteSyncFailure('deleted');
      }
      // An explicit choice: the same payload as a new intent on the current
      // revision. A save still cannot touch the stored privacy trim.
      final body = Map<String, Object?>.from(command)
        ..remove('schemaVersion')
        ..remove('ownerContext')
        ..remove('idempotencyKey')
        ..remove('commandType')
        ..remove('routeId')
        ..remove('expectedRevision');
      _refused.removeAt(index);
      await _enqueue(
        owner,
        _command(
          owner,
          command['commandType']! as String,
          routeId,
          current.revision,
          body,
        ),
      );
    });
  }

  @override
  RouteDraftData draftFrom(
    RouteSyncEntry entry, {
    required RouteDraftData template,
  }) {
    final route = entry.route;
    if (entry.deleted || route is! Map<String, Object?>) {
      throw const RouteSyncFailure('deleted');
    }
    try {
      final snapshot = RouteCanonicalCodec.decode(
        route,
        template: template,
        updatedAtUtc: entry.updatedAtUtc,
      );
      return ApplyRouteEditCommandUseCase(
        idGenerator: _ids,
      ).restoreSnapshot(template, snapshot);
    } on RouteCanonicalFailure catch (error) {
      throw RouteSyncFailure(error.code);
    }
  }
}
