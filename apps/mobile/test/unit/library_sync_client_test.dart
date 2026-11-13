import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/library/data/library_sync_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'a lost response survives client restart and repeats the exact command once',
    () async {
      final server = _Server()..loseResponse = true;
      final first = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        first.mutate(
          action: 'addFavorite',
          objectType: 'place',
          objectId: 'place',
        ),
        throwsA(isA<LibraryFailure>()),
      );
      expect(server.applied, 1);
      final second = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await second.mutate(
        action: 'addFavorite',
        objectType: 'place',
        objectId: 'place',
      );
      expect(server.applied, 1);
      expect(server.commands[0], server.commands[1]);
      expect(second.entries.single['objectId'], 'place');
    },
  );

  test(
    'pending commands are owner-scoped and never replayed into another account',
    () async {
      final server = _Server()..loseResponse = true;
      final client = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        client.mutate(
          action: 'addFavorite',
          objectType: 'place',
          objectId: 'old',
        ),
        throwsA(isA<LibraryFailure>()),
      );
      server.owner = 'owner-b';
      await client.mutate(
        action: 'addFavorite',
        objectType: 'place',
        objectId: 'new',
      );
      expect(server.commands.last['ownerContext'], 'owner-b');
      expect((server.commands.last['payload']! as Map)['objectId'], 'new');
      expect(client.entries.single['objectId'], 'new');
    },
  );

  test(
    'a stale revision is surfaced and does not silently rebase user intent',
    () async {
      final server = _Server()..conflict = true;
      final client = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        client.mutate(
          action: 'addFavorite',
          objectType: 'place',
          objectId: 'place',
        ),
        throwsA(
          isA<LibraryFailure>().having(
            (e) => e.code,
            'code',
            'revision_conflict',
          ),
        ),
      );
      expect(server.commands.length, 1);
      expect(server.applied, 0);
    },
  );

  test('paging restarts atomically after a snapshot changes', () async {
    int calls = 0;
    final client = LibrarySyncClient(
      storage: const FlutterSecureStorage(),
      invoke: (surface, request) async {
        calls++;
        if (calls == 2) return {'kind': 'rejected', 'code': 'snapshot_changed'};
        final revision = calls == 1 ? 1 : 3;
        return {
          'kind': 'succeeded',
          'ownerId': 'owner-a',
          'ownerRevision': revision,
          'entries': [
            _entry(calls == 1 ? 'stale' : 'fresh', 'owner-a', revision),
          ],
          'hasMore': calls == 1,
          'nextRevision': revision,
        };
      },
    );
    await client.refresh();
    expect(calls, 3);
    expect(client.entries.single['objectId'], 'fresh');
  });

  test(
    'replaying a lost successful add cannot claim success after another client removed it',
    () async {
      final server = _Server()..loseResponse = true;
      final first = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        first.mutate(
          action: 'addFavorite',
          objectType: 'place',
          objectId: 'place',
        ),
        throwsA(isA<LibraryFailure>()),
      );
      server.records[server.owner] = [];
      final restarted = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        restarted.mutate(
          action: 'addFavorite',
          objectType: 'place',
          objectId: 'place',
        ),
        throwsA(
          isA<LibraryFailure>().having(
            (e) => e.code,
            'code',
            'revision_conflict',
          ),
        ),
      );
      expect(server.applied, 1);
      expect(restarted.entries, isEmpty);
    },
  );
  test(
    'a plain refresh after restart replays a command that never arrived',
    () async {
      final server = _Server()..failBeforeApply = true;
      final first = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        first.mutate(
          action: 'addFavorite',
          objectType: 'place',
          objectId: 'place',
        ),
        throwsA(isA<LibraryFailure>()),
      );
      expect(server.applied, 0);
      final restarted = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await restarted.refresh();
      expect(server.applied, 1);
      expect(server.commands.length, 1);
      expect(restarted.entries.single['objectId'], 'place');
      await restarted.refresh();
      expect(server.commands.length, 1);
    },
  );

  test(
    'an expired session keeps the pending command for the same owner',
    () async {
      final server = _Server()..failBeforeApply = true;
      final client = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        client.mutate(
          action: 'addFavorite',
          objectType: 'place',
          objectId: 'place',
        ),
        throwsA(isA<LibraryFailure>()),
      );
      server.unauthenticated = true;
      await expectLater(
        client.refresh(),
        throwsA(
          isA<LibraryFailure>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
      expect(client.entries, isEmpty);
      server.unauthenticated = false;
      await client.refresh();
      expect(server.applied, 1);
      expect(client.entries.single['objectId'], 'place');
    },
  );

  test(
    'a terminal rejection of an older unrelated command does not block a new one',
    () async {
      final server = _Server()..failBeforeApply = true;
      final client = LibrarySyncClient(
        invoke: server.invoke,
        storage: const FlutterSecureStorage(),
      );
      await expectLater(
        client.mutate(
          action: 'addFavorite',
          objectType: 'place',
          objectId: 'old',
        ),
        throwsA(isA<LibraryFailure>()),
      );
      server.unavailableObjectId = 'old';
      await client.mutate(
        action: 'addFavorite',
        objectType: 'place',
        objectId: 'new',
      );
      // The rejected replay of 'old' plus the new command.
      expect(server.commands.length, 2);
      expect(client.entries.single['objectId'], 'new');
      await client.refresh();
      expect(server.commands.length, 2);
    },
  );
}

Map<String, Object?> _entry(String objectId, String owner, int revision) => {
  'entryId': objectId,
  'objectId': objectId,
  'ownerId': owner,
  'revision': revision,
  'ownerRevision': revision,
  'status': 'active',
  'kind': 'favorite',
  'objectType': 'place',
  'visitedOn': null,
};

class _Server {
  String owner = 'owner-a';
  bool loseResponse = false;
  bool conflict = false;
  bool failBeforeApply = false;
  bool unauthenticated = false;
  String? unavailableObjectId;
  int applied = 0;
  final receipts = <String, Map<String, Object?>>{};
  final records = <String, List<Map<String, Object?>>>{};
  final commands = <Map<String, Object?>>[];
  Future<Map<String, Object?>> invoke(
    String surface,
    Map<String, Object?> request,
  ) async {
    if (surface == 'libraryQueryV1') {
      if (unauthenticated) {
        return {'kind': 'rejected', 'code': 'unauthenticated'};
      }
      return {
        'kind': 'succeeded',
        'ownerId': owner,
        'ownerRevision': applied,
        'entries': records[owner] ?? [],
        'hasMore': false,
        'nextRevision': applied,
      };
    }
    if (failBeforeApply) {
      failBeforeApply = false;
      throw const LibraryFailure('transport_unavailable');
    }
    commands.add(request);
    if ((request['payload']! as Map)['objectId'] == unavailableObjectId) {
      return {'kind': 'rejected', 'code': 'object_unavailable'};
    }
    if (conflict) return {'kind': 'rejected', 'code': 'revision_conflict'};
    if (request['ownerContext'] != owner) {
      return {'kind': 'rejected', 'code': 'owner_changed'};
    }
    final key = owner + request['idempotencyKey'].toString();
    if (receipts.containsKey(key)) return receipts[key]!;
    applied++;
    final payload = request['payload']! as Map;
    records[owner] = [_entry(payload['objectId'] as String, owner, applied)];
    final result = <String, Object?>{'kind': 'succeeded'};
    receipts[key] = result;
    if (loseResponse) {
      loseResponse = false;
      throw const LibraryFailure('response_lost');
    }
    return result;
  }
}
