import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/server_library_repositories.dart';
import 'package:recharge/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:recharge/features/favorites/data/datasources/favorites_local_datasource.dart';
import 'package:recharge/features/library/data/library_sync_client.dart';

// Server Saved without a network (the owner's metro example). Owner decision
// 2026-11-22 "Оставлять": a revocation keeps this copy on the phone.

const _storage = FlutterSecureStorage();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Object? failure;
  String? signedIn;
  late List<String> served;
  late FavoritesLocalDataSource copy;

  // A new client each time: nothing is kept in memory, as after a restart.
  ServerFavoritesRepository repository() => ServerFavoritesRepository(
    LibrarySyncClient(
      storage: _storage,
      invoke: (surface, request) async {
        if (failure != null) throw failure!;
        return <String, Object?>{
          'kind': 'succeeded',
          'ownerId': 'alice',
          'ownerRevision': 1,
          'hasMore': false,
          'entries': <Object?>[
            for (final id in served)
              <String, Object?>{
                'entryId': 'entry-$id',
                'ownerId': 'alice',
                'kind': 'favorite',
                'status': 'active',
                'revision': 1,
                'objectId': id,
                'objectType': 'event',
                'updatedAtUtc': '2026-11-20T10:00:00.000Z',
                'snapshot': <String, Object?>{
                  'title': 'Kept event',
                  'city': 'Riga',
                  'category': 'culture',
                },
              },
          ],
        };
      },
    ),
    savedCopy: copy,
    currentOwnerId: () async => signedIn,
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    failure = null;
    signedIn = 'alice';
    served = <String>['kept'];
    copy = FavoritesLocalDataSource.savedCopy(
      _storage,
      legacyCurrencyCode: 'EUR',
    );
    expect((await repository().getFavorites()).single.id, 'kept');
  });

  for (final entry in <String, Object>{
    'no connection': const LibraryFailure('unavailable'),
    'a timeout': const LibraryFailure('deadline-exceeded'),
    'a socket failure': const SocketException('offline'),
    'a token that needs the network': FirebaseAuthException(
      code: 'network-request-failed',
    ),
    'a token not armed yet after a cold start': const LibraryFailure(
      'unauthenticated',
    ),
  }.entries) {
    test('after a restart shows the copy on ${entry.key}', () async {
      failure = entry.value;
      final items = await repository().getFavorites();
      expect(items.single.id, 'kept');
      expect(items.single.title, 'Kept event');
      expect(items.single.objectType, 'event');
    });
  }

  test('an empty server list is an empty copy, not an old one', () async {
    served = <String>[];
    expect(await repository().getFavorites(), isEmpty);
    failure = const LibraryFailure('unavailable');
    expect(await repository().getFavorites(), isEmpty);
  });

  test('without a copy the failure is shown, not "nothing saved"', () async {
    FlutterSecureStorage.setMockInitialValues({});
    failure = const LibraryFailure('unavailable');
    await expectLater(
      repository().getFavorites(),
      throwsA(isA<LibraryFailure>()),
    );
  });

  for (final owner in <String?>['bob', null]) {
    test('never shows the copy to ${owner ?? 'a guest'}', () async {
      failure = const LibraryFailure('unavailable');
      signedIn = owner;
      await expectLater(
        repository().getFavorites(),
        throwsA(isA<LibraryFailure>()),
      );
    });
  }

  for (final code in <String>['processing_restricted', 'internal']) {
    test('$code is shown, not hidden behind the copy', () async {
      failure = LibraryFailure(code);
      await expectLater(
        repository().getFavorites(),
        throwsA(isA<LibraryFailure>()),
      );
    });
  }

  test(
    'the copy never replaces the list that lives only on the phone',
    () async {
      final local = FavoritesLocalDataSource(
        _storage,
        legacyCurrencyCode: 'EUR',
      );
      expect(await local.readFavorites('alice'), isEmpty);
    },
  );

  test('a revocation keeps the copy for the same account', () async {
    // A revocation only forgets the offline profile (owner 2026-11-23).
    await const AuthLocalDataSource(_storage).clearOfflineProfile();
    failure = const LibraryFailure('unavailable');
    expect((await repository().getFavorites()).single.id, 'kept');
  });
}
