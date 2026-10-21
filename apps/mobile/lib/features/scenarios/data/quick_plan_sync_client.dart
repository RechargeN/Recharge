import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/scenario_draft_entity.dart';
import '../domain/repositories/quick_plan_repository.dart';
import 'quick_plan_codec.dart';

typedef QuickPlanInvoke =
    Future<Map<String, Object?>> Function(String, Map<String, Object?>);

class QuickPlanFailure implements Exception {
  const QuickPlanFailure(this.code);
  final String code;
  @override
  String toString() => 'QuickPlanFailure($code)';
}

/// A single atomic encrypted journal per installation/owner. No authority from cache.
class QuickPlanSyncClient implements QuickPlanRepository {
  QuickPlanSyncClient({
    required QuickPlanInvoke invoke,
    required FlutterSecureStorage storage,
    required String installationId,
    required String? Function() currentOwner,
  }) : _invoke = invoke,
       _storage = storage,
       _installation = installationId,
       _currentOwner = currentOwner;
  final QuickPlanInvoke _invoke;
  final FlutterSecureStorage _storage;
  final String _installation;
  final String? Function() _currentOwner;
  @override
  String? get actorId => _currentOwner();
  Future<void> _tail = Future.value();
  String? _visibleOwner;
  Map<String, dynamic> _journal = {};
  String _key(String owner) =>
      'quick_plan_v1_${base64Url.encode(utf8.encode('$_installation:$owner'))}';
  String _check(String owner) {
    if (_currentOwner() != owner) {
      _journal = {};
      _visibleOwner = null;
      throw const QuickPlanFailure('owner_changed');
    }
    return owner;
  }

  @override
  List<Map<String, Object?>> get conflicts => _visibleOwner == _currentOwner()
      ? List.unmodifiable(
          (_journal['conflicts'] as List? ?? []).map(
            (e) => Map<String, Object?>.from(e as Map),
          ),
        )
      : const [];
  @override
  ScenarioDraftEntity? cached(String id) {
    if (_visibleOwner != _currentOwner()) return null;
    final entry = (_journal['cache'] as Map?)?[id];
    if (entry is Map && entry['status'] == 'deleted') return null;
    // Offline drafts survive a restart even before a server save is possible.
    for (final raw in (_journal['pending'] as List? ?? []).reversed) {
      final request = raw as Map;
      if (!['save', 'delete', 'import'].contains(request['commandType'])) {
        continue;
      }
      if (request['planId'] == id) {
        return request['commandType'] == 'delete'
            ? null
            : decodeQuickPlan(request['plan']);
      }
    }
    return entry is Map && entry['status'] == 'active'
        ? decodeQuickPlan(entry['plan'])
        : null;
  }

  @override
  int? serverRevision(String id) {
    if (_visibleOwner != _currentOwner()) return null;
    final entry = (_journal['cache'] as Map?)?[id];
    return entry is Map ? entry['revision'] as int? : null;
  }

  @override
  bool hasPending(String id) =>
      _visibleOwner == _currentOwner() &&
      (_journal['pending'] as List? ?? []).any(
        (e) => (e as Map)['planId'] == id,
      );

  Future<T> _serial<T>(Future<T> Function() f) {
    final r = _tail.then((_) => f());
    _tail = r.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return r;
  }

  Future<void> _load(String owner) async {
    _check(owner);
    final raw = await _storage.read(key: _key(owner));
    _check(owner);
    _journal = raw == null
        ? {'pending': [], 'conflicts': [], 'cache': {}}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    _visibleOwner = owner;
  }

  Future<void> _persist(String owner) async {
    _check(owner);
    await _storage.write(key: _key(owner), value: jsonEncode(_journal));
    _check(owner);
  }

  /// Logout callers may clear eagerly; owner callback also hides data synchronously.
  @override
  void clearVisible() {
    _journal = {};
    _visibleOwner = null;
  }

  @override
  Future<void> restore() => _serial(() async {
    final owner = _currentOwner();
    if (owner == null) {
      clearVisible();
      return;
    }
    await _load(owner);
  });
  @override
  Future<void> save(
    ScenarioDraftEntity plan, {
    required int expectedRevision,
  }) => _enqueue('save', plan.id, expectedRevision, plan, null);
  @override
  Future<void> delete(String id, {required int expectedRevision}) =>
      _enqueue('delete', id, expectedRevision, null, null);
  @override
  Future<void> importJson(String source) {
    final p = parseQuickPlanImport(source);
    return _enqueue('import', p.id, 0, p, quickPlanImportKey(p));
  }

  @override
  Future<List<QuickPlanInvitation>> invitations() => _serial(() async {
    final actor = _currentOwner();
    if (actor == null) throw const QuickPlanFailure('unauthenticated');
    await _load(actor);
    await _drain(actor);
    final r = await _invoke('quickPlanQueryV1', {
      'schemaVersion': 1,
      'requestId': const Uuid().v4(),
      'queryType': 'invitations',
    });
    _check(actor);
    if (r['kind'] != 'succeeded') {
      throw QuickPlanFailure(r['code'] as String? ?? 'answer_invalid');
    }
    if (r['ownerId'] != actor) throw const QuickPlanFailure('owner_changed');
    return (r['invitations'] as List)
        .map((g) => QuickPlanInvitation.fromMap(g as Map))
        .toList();
  });

  @override
  Future<void> invite(
    String planId,
    String userId, {
    QuickPlanInvitation? previous,
  }) => _access(
    'invite',
    QuickPlanInvitation(
      planId: planId,
      ownerId: _currentOwner() ?? '',
      inviteeId: userId,
      invitationId: const Uuid().v4(),
      generation: previous?.generation ?? 0,
      status: previous?.status ?? 'none',
    ),
  );

  @override
  Future<void> invitationAction(String action, QuickPlanInvitation invitation) {
    if (!['accept', 'decline', 'cancel', 'revoke', 'leave'].contains(action)) {
      return Future.error(const QuickPlanFailure('request_invalid'));
    }
    return _access(action, invitation);
  }

  Future<void> _access(String action, QuickPlanInvitation g) {
    final actor = _currentOwner();
    if (actor == null) {
      return Future.error(const QuickPlanFailure('unauthenticated'));
    }
    return _serial(() async {
      _check(actor);
      await _load(actor);
      (_journal['pending'] as List).add({
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'ownerContext': actor,
        'idempotencyKey': const Uuid().v4(),
        'commandType': action,
        'planId': g.planId,
        'expectedRevision': 0,
        'planOwnerId': g.ownerId,
        'targetUserId': g.inviteeId,
        'invitationId': g.invitationId,
        'generation': g.generation,
        if (action == 'invite') 'previousStatus': g.status,
      });
      await _persist(actor);
      await _drain(actor);
    });
  }

  /// Online-only projection. Never put invited payload into cache, conflicts or journal.
  @override
  Future<ScenarioDraftEntity> readInvited(QuickPlanInvitation g) => _serial(
    () async {
      final actor = _currentOwner();
      if (actor == null) throw const QuickPlanFailure('unauthenticated');
      await _load(actor);
      await _drain(actor);
      final r = await _invoke('quickPlanQueryV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'planId': g.planId,
        'planOwnerId': g.ownerId,
        'invitationId': g.invitationId,
        'generation': g.generation,
      });
      _check(actor);
      if (r['kind'] != 'succeeded') {
        throw QuickPlanFailure(r['code'] as String? ?? 'answer_invalid');
      }
      if (r['ownerId'] != actor) throw const QuickPlanFailure('owner_changed');
      final entry = r['entry'] as Map?;
      if (entry?['status'] != 'active') {
        throw const QuickPlanFailure('access_revoked');
      }
      return decodeQuickPlan(entry!['plan']);
    },
  );

  Future<void> _enqueue(
    String type,
    String id,
    int revision,
    ScenarioDraftEntity? plan,
    String? key,
  ) {
    final owner = _currentOwner();
    if (owner == null) {
      return Future.error(const QuickPlanFailure('unauthenticated'));
    }
    final dto = plan == null ? null : encodeQuickPlan(plan);
    if (dto != null) decodeQuickPlan(dto);
    return _serial(() async {
      _check(owner);
      await _load(owner);
      final pending = _journal['pending'] as List;
      final request = <String, Object?>{
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'ownerContext': owner,
        'idempotencyKey': key ?? const Uuid().v4(),
        'commandType': type,
        'planId': id,
        'expectedRevision': revision,
        if (dto != null) 'plan': dto,
      };
      if (!pending.any(
        (e) => (e as Map)['idempotencyKey'] == request['idempotencyKey'],
      )) {
        pending.add(request);
      }
      await _persist(owner);
      await _drain(owner);
    });
  }

  Future<Map<String, Object?>> _query(String owner, String id) async {
    _check(owner);
    final r = await _invoke('quickPlanQueryV1', {
      'schemaVersion': 1,
      'requestId': const Uuid().v4(),
      'planId': id,
    });
    _check(owner);
    if (r['kind'] != 'succeeded') {
      throw QuickPlanFailure(r['code'] as String? ?? 'answer_invalid');
    }
    if (r['ownerId'] != owner) throw const QuickPlanFailure('owner_changed');
    return r;
  }

  @override
  Future<void> refresh(String id) => _serial(() async {
    final owner = _currentOwner();
    if (owner == null) {
      clearVisible();
      throw const QuickPlanFailure('unauthenticated');
    }
    await _load(owner);
    // Each pending dispatch verifies the actual session owner in _drain.
    await _drain(owner);
    final r = await _query(owner, id);
    final cache = _journal['cache'] as Map;
    if (r['entry'] == null) {
      cache.remove(id);
    } else {
      cache[id] = r['entry'];
    }
    await _persist(owner);
  });
  Future<void> _drain(String owner) async {
    final pending = _journal['pending'] as List;
    QuickPlanFailure? terminalFailure;
    while (pending.isNotEmpty) {
      _check(owner);
      final request = Map<String, Object?>.from(pending.first as Map);
      // No command is dispatched under an unverified or different session.
      await _query(owner, request['planId']! as String);
      final r = await _invoke('quickPlanCommandV1', request);
      _check(owner);
      if (r['kind'] != 'succeeded' && r['kind'] != 'rejected') {
        throw const QuickPlanFailure('answer_invalid');
      }
      final code = r['code'];
      if (r['kind'] == 'rejected' &&
          ![
            'revision_conflict',
            'deleted',
            'id_collision',
            'idempotency_conflict',
            'request_invalid',
            'access_denied',
            'access_revoked',
            'permission_denied',
            'invite_limit',
            'target_unavailable',
          ].contains(code)) {
        throw QuickPlanFailure(code as String? ?? 'answer_invalid');
      }
      if (r['kind'] == 'rejected') {
        (_journal['conflicts'] as List).add({'request': request, 'result': r});
      } else if ([
        'save',
        'delete',
        'import',
      ].contains(request['commandType'])) {
        // Historical receipt replay must not resurrect a deleted cached plan.
        final current = await _query(owner, request['planId']! as String);
        (_journal['cache'] as Map)[request['planId']] = current['entry'];
      }
      pending.removeAt(0);
      await _persist(owner);
      if (r['kind'] == 'rejected') {
        terminalFailure ??= QuickPlanFailure(code as String? ?? 'rejected');
      }
    }
    if (terminalFailure != null) throw terminalFailure;
  }
}
