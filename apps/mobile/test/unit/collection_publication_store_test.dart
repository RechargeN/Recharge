import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_local_datasource.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_store.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/collection_publication_data.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

/// CLG-PST-01: exercises the persisted store's own crash-safety
/// properties directly — partial-write recovery, restart recovery, and
/// corrupt-record isolation — separately from
/// `collection_publication_repository_impl_test.dart`, which proves the
/// *contract* (idempotency/moderation/removal-only) is unchanged by the
/// store swap.
const _publisher = PublisherRef(type: PublisherType.user, id: 'u1');

CollectionPublishBundle _bundle({
  String collectionId = 'col-1',
  String publishAttemptId = 'attempt-1',
}) {
  return CollectionPublishBundle(
    collectionId: collectionId,
    collectionVersionId: 'v1',
    publisherRef: _publisher,
    title: 'A guide',
    shortDescription: 'Short pitch',
    fullDescription: 'Full description',
    coverMediaId: null,
    marketCityId: 'riga',
    areaLabel: 'Old Town',
    visibility: 'public',
    sections: const <CollectionSectionDraft>[],
    items: const <CollectionItemDraft>[],
    compositionReview: CollectionCompositionReview(
      draftRevision: 1,
      reviewedAtUtc: DateTime.utc(2026),
      acknowledgedUnavailableStableKeys: const <String>{},
    ),
    publishAttemptId: publishAttemptId,
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('restart recovery', () {
    test(
      'a fresh datasource instance over the same store sees what a prior '
      'instance committed — active version, receipt replay, and a pending '
      'moderation request all survive',
      () async {
        const CollectionPublicationStore store = SecureCollectionPublicationStore(
          FlutterSecureStorage(),
        );
        final CollectionPublicationLocalDatasource first =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        await first.publish(_bundle(), actorId: 'actor-1');
        await first.submitForReview(
          _bundle(collectionId: 'col-2', publishAttemptId: 'attempt-2'),
          actorId: 'actor-1',
        );

        // A brand new datasource instance — nothing shared with `first`
        // except the same underlying store — simulates a process restart.
        final CollectionPublicationLocalDatasource restarted =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );

        final PublishedCollectionVersion? active = await restarted
            .activeVersion('col-1');
        expect(active, isNotNull);
        expect(active!.bundle.title, 'A guide');

        // Replay through the restarted instance must still be recognized
        // as the same idempotent write, not a fresh one.
        final CollectionPublishReceipt replay = await restarted.publish(
          _bundle(),
          actorId: 'actor-1',
        );
        expect(replay.outcome, CollectionPublishOutcome.replayedIdempotentSuccess);

        final pending = await restarted.pendingRequests();
        expect(pending, hasLength(1));
        expect(pending.single.collectionId, 'col-2');
      },
    );
  });

  group('partial-write recovery', () {
    test(
      'a crash between the staged write and the active-pointer flip '
      'leaves the active version exactly as it was — nothing partial is '
      'ever observable',
      () async {
        final _FaultInjectingStore store = _FaultInjectingStore(
          const SecureCollectionPublicationStore(FlutterSecureStorage()),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );

        store.failWriteForKey = 'collection_publication_v1.active.col-1';
        await expectLater(
          datasource.publish(_bundle(), actorId: 'actor-1'),
          throwsA(
            isA<CollectionPublicationException>().having(
              (e) => e.failure,
              'failure',
              CollectionPublicationFailure.persistenceUnavailable,
            ),
          ),
        );

        expect(await datasource.activeVersion('col-1'), isNull);

        // The receipt is written only after the active pointer commits —
        // a retry with the fault cleared must be a genuinely fresh write,
        // not blocked by a receipt that should never have been written.
        store.failWriteForKey = null;
        final CollectionPublishReceipt receipt = await datasource.publish(
          _bundle(),
          actorId: 'actor-1',
        );
        expect(receipt.outcome, CollectionPublishOutcome.created);
        expect(await datasource.activeVersion('col-1'), isNotNull);
      },
    );

    test(
      'a crash during the staged write itself (before verification) is '
      'caught by the readback check, not just the pointer-flip write',
      () async {
        final _FaultInjectingStore store = _FaultInjectingStore(
          const SecureCollectionPublicationStore(FlutterSecureStorage()),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );

        store.failWriteForKey = 'collection_publication_v1.staging.col-1';
        await expectLater(
          datasource.publish(_bundle(), actorId: 'actor-1'),
          throwsA(isA<CollectionPublicationException>()),
        );
        expect(await datasource.activeVersion('col-1'), isNull);
      },
    );
  });

  group('corrupt-record isolation', () {
    test(
      'a corrupt active-version record surfaces persistenceUnavailable '
      'for that one collection only — a different, valid collection is '
      'unaffected',
      () async {
        const CollectionPublicationStore store = SecureCollectionPublicationStore(
          FlutterSecureStorage(),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        await datasource.publish(
          _bundle(collectionId: 'col-good'),
          actorId: 'actor-1',
        );
        await store.write(
          'collection_publication_v1.active.col-bad',
          '{not valid json',
        );

        expect(
          () => datasource.activeVersion('col-bad'),
          throwsA(
            isA<CollectionPublicationException>().having(
              (e) => e.failure,
              'failure',
              CollectionPublicationFailure.persistenceUnavailable,
            ),
          ),
        );
        final PublishedCollectionVersion? good = await datasource
            .activeVersion('col-good');
        expect(good, isNotNull);
        expect(good!.bundle.collectionId, 'col-good');
      },
    );

    test(
      'a corrupt moderation request is skipped by pendingRequests(), other '
      'pending requests still come back',
      () async {
        const CollectionPublicationStore store = SecureCollectionPublicationStore(
          FlutterSecureStorage(),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        await datasource.submitForReview(
          _bundle(collectionId: 'col-good', publishAttemptId: 'attempt-good'),
          actorId: 'actor-1',
        );
        await store.write(
          'collection_publication_v1.moderation.attempt-bad',
          '{not valid json',
        );

        final pending = await datasource.pendingRequests();
        expect(pending, hasLength(1));
        expect(pending.single.collectionId, 'col-good');
      },
    );

    test(
      'a tampered content_hash is treated the same as malformed JSON — the '
      'record is corrupt, not silently trusted',
      () async {
        const CollectionPublicationStore store = SecureCollectionPublicationStore(
          FlutterSecureStorage(),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        await datasource.publish(_bundle(), actorId: 'actor-1');
        final String key = 'collection_publication_v1.active.col-1';
        final String original = (await store.read(key))!;
        final String tampered = original.replaceFirst(
          '"title":"A guide"',
          '"title":"Tampered title"',
        );
        // Only meaningful if the naive string replace actually changed
        // something (guards against the fixture drifting silently).
        expect(tampered, isNot(original));
        await store.write(key, tampered);

        expect(
          () => datasource.activeVersion('col-1'),
          throwsA(isA<CollectionPublicationException>()),
        );
      },
    );
  });
}

class _SequentialIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String generate() => 'gen-${_counter++}';
}

class _FaultInjectingStore implements CollectionPublicationStore {
  _FaultInjectingStore(this._backing);

  final CollectionPublicationStore _backing;
  String? failWriteForKey;

  @override
  Future<String?> read(String key) => _backing.read(key);

  @override
  Future<void> write(String key, String value) async {
    if (key == failWriteForKey) {
      throw StateError('simulated crash writing $key');
    }
    return _backing.write(key, value);
  }

  @override
  Future<void> delete(String key) => _backing.delete(key);

  @override
  Future<Map<String, String>> readAllWithPrefix(String prefix) =>
      _backing.readAllWithPrefix(prefix);
}
