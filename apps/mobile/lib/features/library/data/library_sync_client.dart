import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/primitives/errors/coded_refusal.dart';

typedef LibraryInvoke =
    Future<Map<String, Object?>> Function(String, Map<String, Object?>);

final class LibraryFailure implements CodedRefusal {
  const LibraryFailure(this.code);
  @override
  final String code;
  @override
  UserMessageFamily get messageFamily => UserMessageFamily.library;
  @override
  String toString() => 'LibraryFailure($code)';
}

/// Server-owned Library, refreshed explicitly by the existing screens.
/// No local/demo import, background worker or guessed success on transport failure.
final class LibrarySyncClient {
  LibrarySyncClient({
    required LibraryInvoke invoke,
    required FlutterSecureStorage storage,
    String Function()? newId,
  }) : _invoke = invoke,
       _storage = storage,
       _newId = newId ?? const Uuid().v4;

  final LibraryInvoke _invoke;
  final FlutterSecureStorage _storage;
  final String Function() _newId;
  Future<void> _tail = Future<void>.value();
  Map<String, Map<String, Object?>> _entries = {};
  String? _owner;
  String? get ownerId => _owner;
  List<Map<String, Object?>> get entries => _entries.values
      .where((entry) => entry['status'] == 'active')
      .toList(growable: false);

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static String _pendingKey(String owner) =>
      'library_pending_v1_${base64Url.encode(utf8.encode(owner))}';

  /// Reads the server snapshot, then retries a command left pending by a lost
  /// response or a process restart, so recovery does not wait for a new action.
  Future<void> refresh() => _serial(() async {
    await _refresh();
    await _drainPending();
  });

  /// Best-effort replay of the owner's pending command. A transport failure
  /// keeps it for the next attempt; a terminal answer resolves it, and the
  /// server snapshot shows the outcome. A refresh never fails because of it.
  Future<void> _drainPending() async {
    final owner = _owner;
    if (owner == null) return;
    final pendingKey = _pendingKey(owner);
    final saved = await _storage.read(key: pendingKey);
    if (saved == null) return;
    final pending = jsonDecode(saved) as Map<String, dynamic>;
    try {
      await _send(
        Map<String, Object?>.from(pending['request'] as Map),
        pendingKey,
      );
    } on LibraryFailure {
      return;
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    // Publish only a complete revision-pinned snapshot, including tombstones.
    for (int attempt = 0; attempt < 3; attempt++) {
      final next = <String, Map<String, Object?>>{};
      int after = 0;
      int? revision;
      String? owner;
      bool restart = false;
      for (int page = 0; page < 1000; page++) {
        final answer = await _invoke('libraryQueryV1', {
          'schemaVersion': 1,
          'requestId': _newId(),
          'afterRevision': after,
          'limit': 100,
          if (revision != null) 'expectedOwnerRevision': revision,
        });
        if (answer['code'] == 'snapshot_changed') {
          restart = true;
          break;
        }
        if ([
          'unauthenticated',
          'processing_restricted',
          'owner_changed',
        ].contains(answer['code'])) {
          final knownOwner = _owner;
          _entries = {};
          _owner = null;
          // An expired session keeps the owner-scoped queue for the same owner's
          // next Session; a restricted/erased owner's commands can never apply.
          if (knownOwner != null && answer['code'] == 'processing_restricted') {
            await _storage.delete(key: _pendingKey(knownOwner));
          }
        }
        _succeeded(answer);
        final rawEntries = answer['entries'];
        final currentOwner = answer['ownerId'];
        final currentRevision = answer['ownerRevision'];
        if (rawEntries is! List ||
            currentOwner is! String ||
            currentRevision is! int ||
            (owner != null && owner != currentOwner)) {
          throw const LibraryFailure('answer_invalid');
        }
        owner = currentOwner;
        revision = currentRevision;
        if (_owner != null && _owner != owner) {
          _entries = {};
          _owner = null;
        }
        for (final raw in rawEntries) {
          if (raw is! Map) throw const LibraryFailure('answer_invalid');
          final entry = Map<String, Object?>.from(raw);
          if (entry['ownerId'] != owner ||
              entry['entryId'] is! String ||
              entry['objectId'] is! String ||
              entry['revision'] is! int ||
              !['active', 'removed'].contains(entry['status'])) {
            throw const LibraryFailure('answer_invalid');
          }
          next[entry['entryId']! as String] = entry;
        }
        if (answer['hasMore'] == false) {
          _owner = owner;
          _entries = next;
          return;
        }
        final cursor = answer['nextRevision'];
        if (cursor is! int || cursor <= after || cursor > revision) {
          throw const LibraryFailure('answer_invalid');
        }
        after = cursor;
      }
      if (!restart) throw const LibraryFailure('page_limit_exceeded');
    }
    throw const LibraryFailure('snapshot_changed');
  }

  Future<void> mutate({
    required String action,
    required String objectType,
    required String objectId,
    String? visitedOn,
  }) => _serial(() async {
    await _refresh();
    final owner = _owner!;
    final pendingKey = _pendingKey(owner);
    final logical = jsonEncode([action, objectType, objectId, visitedOn]);
    final saved = await _storage.read(key: pendingKey);
    if (saved != null) {
      final pending = jsonDecode(saved) as Map<String, dynamic>;
      final request = Map<String, Object?>.from(pending['request'] as Map);
      final sameIntent = pending['logical'] == logical;
      try {
        await _send(request, pendingKey);
      } on LibraryFailure {
        // A transport failure keeps the older command queued and blocks this
        // one; a terminal rejection of an unrelated older command does not.
        if (sameIntent || await _storage.read(key: pendingKey) != null) {
          rethrow;
        }
      }
      await _refresh();
      if (sameIntent) {
        final active = entries.any(
          (e) =>
              e['objectType'] == objectType &&
              e['objectId'] == objectId &&
              e['visitedOn'] == visitedOn &&
              e['kind'] == (action.endsWith('Favorite') ? 'favorite' : 'visit'),
        );
        if (active != !action.startsWith('remove')) {
          throw const LibraryFailure('revision_conflict');
        }
        return;
      }
    }
    final kind = action.endsWith('Favorite') ? 'favorite' : 'visit';
    final matches = _entries.values.where(
      (e) =>
          e['kind'] == kind &&
          e['objectType'] == objectType &&
          e['objectId'] == objectId &&
          e['visitedOn'] == visitedOn,
    );
    final current = matches.firstOrNull;
    final request = <String, Object?>{
      'schemaVersion': 1,
      'requestId': _newId(),
      'ownerContext': owner,
      'idempotencyKey': _newId(),
      'commandType': action,
      'payload': <String, Object?>{
        'objectId': objectId,
        'objectType': objectType,
        'proposedEntryId': current?['entryId'] ?? _newId(),
        'expectedRevision': current?['revision'] ?? 0,
        if (visitedOn != null) 'visitedOn': visitedOn,
      },
    };
    // Persist before dispatch so a lost response repeats the exact same command.
    await _storage.write(
      key: pendingKey,
      value: jsonEncode({'logical': logical, 'request': request}),
    );
    await _send(request, pendingKey);
    await _refresh();
  });

  Future<void> _send(Map<String, Object?> request, String pendingKey) async {
    final answer = await _invoke('libraryCommandV1', request);
    if (answer['kind'] == 'succeeded' || answer['kind'] == 'rejected') {
      await _storage.delete(key: pendingKey);
    }
    _succeeded(answer);
  }

  static void _succeeded(Map<String, Object?> answer) {
    if (answer['kind'] != 'succeeded') {
      throw LibraryFailure(
        answer['code'] is String ? answer['code']! as String : 'answer_invalid',
      );
    }
  }
}
