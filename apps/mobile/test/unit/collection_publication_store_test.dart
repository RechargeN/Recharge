import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_local_datasource.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_store.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/collection_publication_data.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

/// CLG-PST-01/CLG-PST-02: exercises the persisted store's own crash-safety
/// properties directly — partial-write recovery, restart recovery, and
/// corrupt-record isolation — separately from
/// `collection_publication_repository_impl_test.dart`, which proves the
/// *contract* (idempotency/moderation/removal-only) is unchanged by the
/// store swap.
///
/// CLG-PST-02 correction: CLG-PST-01's own crash-matrix here only ever
/// faulted the old `active.<id>`/`staging.<id>` keys and never proved the
/// write that actually mattered (the active-key write itself) was
/// verified. This file now targets the real key scheme
/// (`version.<id>.<versionId>` / `pointer.<id>` / `pointer.<id>.previous` /
/// `tombstone.<id>` / `audit.<id>.<requestId>`) and adds the cases the
/// review found missing: a torn pointer write, the removal-only
/// effect/receipt crash gap, archive-retry re-attempting the sink-adjacent
/// local state, and typed-failure wrapping on paths CLG-PST-01 left
/// unwrapped.
const _publisher = PublisherRef(type: PublisherType.user, id: 'u1');

CollectionPublishBundle _bundle({
  String collectionId = 'col-1',
  String versionId = 'v1',
  String publishAttemptId = 'attempt-1',
}) {
  return CollectionPublishBundle(
    collectionId: collectionId,
    collectionVersionId: versionId,
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
      'a crash writing the version record itself is caught by that '
      'write\'s own readback check — no pointer ever ends up naming an '
      'unreadable version',
      () async {
        final _FaultInjectingStore store = _FaultInjectingStore(
          const SecureCollectionPublicationStore(FlutterSecureStorage()),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );

        store.failWriteForKey = 'collection_publication_v1.version.col-1.v1';
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
      'CLG-PST-01 review finding: a crash writing the pointer itself — the '
      'record CLG-PST-01 never verified — leaves the previous active '
      'version exactly as it was, not partially overwritten',
      () async {
        final _FaultInjectingStore store = _FaultInjectingStore(
          const SecureCollectionPublicationStore(FlutterSecureStorage()),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );

        // First publish succeeds cleanly and becomes last-known-good.
        await datasource.publish(_bundle(), actorId: 'actor-1');
        final PublishedCollectionVersion? before = await datasource
            .activeVersion('col-1');
        expect(before, isNotNull);

        // A second, different publish attempt now fails exactly at the
        // pointer write.
        store.failWriteForKey = 'collection_publication_v1.pointer.col-1';
        await expectLater(
          datasource.publish(
            _bundle(versionId: 'v2', publishAttemptId: 'attempt-2'),
            actorId: 'actor-1',
          ),
          throwsA(
            isA<CollectionPublicationException>().having(
              (e) => e.failure,
              'failure',
              CollectionPublicationFailure.persistenceUnavailable,
            ),
          ),
        );

        // The pointer was never flipped — the original version is still
        // exactly what reads back, not a torn mix of old and new.
        final PublishedCollectionVersion? after = await datasource
            .activeVersion('col-1');
        expect(after, isNotNull);
        expect(after!.collectionVersionId, before!.collectionVersionId);
      },
    );

    test(
      'a corrupt current pointer falls back to the last-known-good '
      '.previous pointer instead of surfacing as data loss',
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
        // A second publish makes `pointer.col-1.previous` exist, pointing
        // at the first version.
        await datasource.publish(
          _bundle(versionId: 'v2', publishAttemptId: 'attempt-2'),
          actorId: 'actor-1',
        );
        expect(
          (await datasource.activeVersion('col-1'))!.collectionVersionId,
          'v2',
        );

        // Now corrupt only the *current* pointer.
        await store.write(
          'collection_publication_v1.pointer.col-1',
          '{not valid json',
        );

        final PublishedCollectionVersion? recovered = await datasource
            .activeVersion('col-1');
        expect(recovered, isNotNull);
        expect(recovered!.collectionVersionId, 'v1'); // last-known-good
      },
    );

    test(
      'removeItemsOnly review finding: a crash between committing the new '
      'version and writing its receipt is recovered as an idempotent '
      'replay, not a spurious revisionConflict',
      () async {
        final _FaultInjectingStore store = _FaultInjectingStore(
          const SecureCollectionPublicationStore(FlutterSecureStorage()),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        final CollectionItemDraft item = CollectionItemDraft(
          id: 'item-1',
          ref: const CollectionObjectRef(
            objectId: 'p1',
            objectType: CollectionCatalogObjectType.place,
          ),
          snapshot: const CollectionItemSnapshotDraft(title: 'Place one'),
          sourceStatus: CollectionSourceStatus.ready,
          order: 0,
        );
        await datasource.publish(
          _bundle().copyWith(items: <CollectionItemDraft>[item]),
          actorId: 'actor-1',
        );
        final PublishedCollectionVersion published = (await datasource
            .activeVersion('col-1'))!;

        final CollectionRemovalOnlyCommand command = CollectionRemovalOnlyCommand(
          collectionId: 'col-1',
          baseVersionId: published.collectionVersionId,
          expectedBaseRevisionOrHash: published.collectionVersionId,
          removedItemRefs: <String>{item.ref.stableKey},
          requestId: 'removal-1',
          actorId: 'actor-1',
        );

        // The removal's own receipt write is the one that fails — the new
        // (emptied-of-item) version already committed by the time this
        // throws.
        store.failWriteForKey =
            'collection_publication_v1.receipt.removal.col-1.removal-1';
        await expectLater(
          datasource.removeItemsOnly(command),
          throwsA(isA<CollectionPublicationException>()),
        );

        // A retry of the exact same command must not see the base-revision
        // check fail against the version it itself already committed.
        store.failWriteForKey = null;
        final CollectionPublishReceipt receipt = await datasource
            .removeItemsOnly(command);
        expect(receipt.outcome, CollectionPublishOutcome.created);
        expect(
          (await datasource.activeVersion('col-1'))!.bundle.items,
          isEmpty,
        );
      },
    );
  });

  group('archive tombstone', () {
    test(
      'CLG-PST-01 review finding: a retried archive() after a sink failure '
      'still has a local record to sync against — it is not deleted on '
      'first archive',
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

        final bool firstArchive = await datasource.archive(
          'col-1',
          actorId: 'actor-1',
        );
        expect(firstArchive, isTrue);
        expect(await datasource.activeVersion('col-1'), isNull);

        // A second archive call on the same, already-archived collection
        // must still report "has a record" so the repository layer above
        // re-attempts the Discover sink — this is the fix.
        final bool secondArchive = await datasource.archive(
          'col-1',
          actorId: 'actor-1',
        );
        expect(secondArchive, isTrue);
      },
    );

    test(
      'archiving a never-published collectionId reports no record, ever',
      () async {
        const CollectionPublicationStore store = SecureCollectionPublicationStore(
          FlutterSecureStorage(),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        expect(
          await datasource.archive('never-published', actorId: 'actor-1'),
          isFalse,
        );
      },
    );

    test(
      'a republish after an archive supersedes the old tombstone — the '
      'fresh version reads back as active, not archived',
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
        await datasource.archive('col-1', actorId: 'actor-1');
        expect(await datasource.activeVersion('col-1'), isNull);

        await datasource.publish(
          _bundle(versionId: 'v2', publishAttemptId: 'attempt-2'),
          actorId: 'actor-1',
        );
        final PublishedCollectionVersion? active = await datasource
            .activeVersion('col-1');
        expect(active, isNotNull);
        expect(active!.collectionVersionId, 'v2');
      },
    );
  });

  group('audit trail', () {
    test(
      'publish, removeItemsOnly and archive each leave an audit record '
      'naming the real actor and, for removal, the diff',
      () async {
        const CollectionPublicationStore store = SecureCollectionPublicationStore(
          FlutterSecureStorage(),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        final CollectionItemDraft item = CollectionItemDraft(
          id: 'item-1',
          ref: const CollectionObjectRef(
            objectId: 'p1',
            objectType: CollectionCatalogObjectType.place,
          ),
          snapshot: const CollectionItemSnapshotDraft(title: 'Place one'),
          sourceStatus: CollectionSourceStatus.ready,
          order: 0,
        );
        await datasource.publish(
          _bundle().copyWith(items: <CollectionItemDraft>[item]),
          actorId: 'actor-1',
        );
        final Map<String, String> afterPublish = await store
            .readAllWithPrefix('collection_publication_v1.audit.col-1.');
        expect(afterPublish, hasLength(1));
        expect(afterPublish.values.single, contains('"actor_id":"actor-1"'));
        expect(afterPublish.values.single, contains('"command_type":"publish"'));

        await datasource.removeItemsOnly(
          CollectionRemovalOnlyCommand(
            collectionId: 'col-1',
            baseVersionId: 'v1',
            expectedBaseRevisionOrHash: 'v1',
            removedItemRefs: <String>{item.ref.stableKey},
            requestId: 'removal-1',
            actorId: 'actor-2',
          ),
        );
        final String removalAudit = (await store.read(
          'collection_publication_v1.audit.col-1.removal-1',
        ))!;
        expect(removalAudit, contains('"actor_id":"actor-2"'));
        expect(removalAudit, contains(item.ref.stableKey));

        await datasource.archive('col-1', actorId: 'actor-3', requestId: 'arch-1');
        final String archiveAudit = (await store.read(
          'collection_publication_v1.audit.col-1.arch-1',
        ))!;
        expect(archiveAudit, contains('"actor_id":"actor-3"'));
        expect(archiveAudit, contains('"command_type":"archive"'));
      },
    );

    test(
      'a corrupt audit record is not read by any production path — it '
      'never blocks reading the active version',
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
        await store.write(
          'collection_publication_v1.audit.col-1.some-other-request',
          '{not valid json',
        );

        final PublishedCollectionVersion? active = await datasource
            .activeVersion('col-1');
        expect(active, isNotNull);
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
        // Corrupt col-bad's pointer directly (never published through the
        // datasource, so there is no valid version record to fall back to
        // either).
        await store.write(
          'collection_publication_v1.pointer.col-bad',
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
        final String key = 'collection_publication_v1.version.col-1.v1';
        final String original = (await store.read(key))!;
        final String tampered = original.replaceFirst(
          '"title":"A guide"',
          '"title":"Tampered title"',
        );
        expect(tampered, isNot(original));
        await store.write(key, tampered);

        expect(
          () => datasource.activeVersion('col-1'),
          throwsA(isA<CollectionPublicationException>()),
        );
      },
    );
  });

  group('typed-failure wrapping', () {
    test(
      'a raw storage exception from pendingRequests() surfaces as '
      'persistenceUnavailable, not an unhandled exception',
      () async {
        final _FaultInjectingReadAllStore store = _FaultInjectingReadAllStore(
          const SecureCollectionPublicationStore(FlutterSecureStorage()),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        store.failReadAll = true;
        await expectLater(
          datasource.pendingRequests(),
          throwsA(
            isA<CollectionPublicationException>().having(
              (e) => e.failure,
              'failure',
              CollectionPublicationFailure.persistenceUnavailable,
            ),
          ),
        );
      },
    );

    test(
      'a raw storage exception reading a moderation request in decide() '
      'surfaces as persistenceUnavailable',
      () async {
        final _FaultInjectingStore store = _FaultInjectingStore(
          const SecureCollectionPublicationStore(FlutterSecureStorage()),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        await datasource.submitForReview(_bundle(), actorId: 'actor-1');
        store.failReadForKey = 'collection_publication_v1.moderation.attempt-1';
        await expectLater(
          datasource.decide(
            requestId: 'attempt-1',
            accept: true,
            decidedByActorId: 'mod-1',
          ),
          throwsA(
            isA<CollectionPublicationException>().having(
              (e) => e.failure,
              'failure',
              CollectionPublicationFailure.persistenceUnavailable,
            ),
          ),
        );
      },
    );

    test(
      'a raw storage exception inside archive() surfaces as '
      'persistenceUnavailable',
      () async {
        final _FaultInjectingStore store = _FaultInjectingStore(
          const SecureCollectionPublicationStore(FlutterSecureStorage()),
        );
        final CollectionPublicationLocalDatasource datasource =
            CollectionPublicationLocalDatasource(
              idGenerator: _SequentialIdGenerator(),
              store: store,
            );
        await datasource.publish(_bundle(), actorId: 'actor-1');
        store.failWriteForKey = 'collection_publication_v1.tombstone.col-1';
        await expectLater(
          datasource.archive('col-1', actorId: 'actor-1'),
          throwsA(
            isA<CollectionPublicationException>().having(
              (e) => e.failure,
              'failure',
              CollectionPublicationFailure.persistenceUnavailable,
            ),
          ),
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
  String? failReadForKey;

  @override
  Future<String?> read(String key) {
    if (key == failReadForKey) {
      throw StateError('simulated crash reading $key');
    }
    return _backing.read(key);
  }

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

class _FaultInjectingReadAllStore implements CollectionPublicationStore {
  _FaultInjectingReadAllStore(this._backing);

  final CollectionPublicationStore _backing;
  bool failReadAll = false;

  @override
  Future<String?> read(String key) => _backing.read(key);

  @override
  Future<void> write(String key, String value) => _backing.write(key, value);

  @override
  Future<void> delete(String key) => _backing.delete(key);

  @override
  Future<Map<String, String>> readAllWithPrefix(String prefix) {
    if (failReadAll) {
      throw StateError('simulated crash enumerating $prefix');
    }
    return _backing.readAllWithPrefix(prefix);
  }
}
