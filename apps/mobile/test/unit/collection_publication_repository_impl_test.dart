import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/collection_publication_discovery_adapter.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_local_datasource.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_store.dart';
import 'package:recharge/features/create/data/repositories/collection_publication_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/collection_moderation_request.dart';
import 'package:recharge/features/create/domain/entities/collection_publication_data.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/collection_publication_index_sink.dart';
import 'package:recharge/features/create/domain/repositories/collection_publication_repository.dart';
import 'package:recharge/features/discover/data/datasources/published_collection_discovery_local_datasource.dart';

const _publisher = PublisherRef(type: PublisherType.user, id: 'u1');
const String _actor = 'actor-1';

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
  late CollectionPublicationLocalDatasource datasource;
  late _RecordingSink sink;
  late CollectionPublicationRepositoryImpl repository;
  late _FakeIdGenerator idGenerator;

  setUp(() {
    // CLG-PST-01: the datasource is now backed by a real persisted store —
    // this whole suite proves the store swap did not change the contract,
    // not just the coordinator/repository layers above it.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    idGenerator = _FakeIdGenerator();
    datasource = CollectionPublicationLocalDatasource(
      idGenerator: idGenerator,
      store: const SecureCollectionPublicationStore(FlutterSecureStorage()),
    );
    sink = _RecordingSink();
    repository = CollectionPublicationRepositoryImpl(
      datasource: datasource,
      sink: sink,
    );
  });

  group('publish idempotency', () {
    test('replaying the same attempt id and payload returns the original '
        'receipt, not a new write', () async {
      final CollectionPublishReceipt first = await repository.publish(
        _bundle(),
        actorId: _actor,
      );
      final CollectionPublishReceipt replay = await repository.publish(
        _bundle(),
        actorId: _actor,
      );

      expect(first.outcome, CollectionPublishOutcome.created);
      expect(replay.outcome, CollectionPublishOutcome.replayedIdempotentSuccess);
      expect(replay.collectionId, first.collectionId);
      expect(sink.activateCalls, hasLength(2)); // both calls sync the sink
    });

    test('the same attempt id with a different payload is an idempotency '
        'conflict', () async {
      await repository.publish(_bundle(), actorId: _actor);
      expect(
        () => repository.publish(
          _bundle(collectionId: 'col-2'),
          actorId: _actor,
        ),
        throwsA(
          isA<CollectionPublicationException>().having(
            (e) => e.failure,
            'failure',
            CollectionPublicationFailure.idempotencyConflict,
          ),
        ),
      );
    });

    test(
      'submitForReview and publish never share an idempotency key, even '
      'with the identical bundle/actor — a review replay can never be read '
      'back as a successful publish, and vice versa (the review finding)',
      () async {
        final CollectionPublishReceipt reviewReceipt = await repository
            .submitForReview(_bundle(), actorId: _actor);
        expect(reviewReceipt.outcome, CollectionPublishOutcome.pendingReview);
        expect(await repository.getActiveVersion('col-1'), isNull);

        // Same bundle (same publishAttemptId/actor), now through publish().
        // Must be a genuine, independent write — not a replay of the review
        // receipt reinterpreted as a publish.
        final CollectionPublishReceipt publishReceipt = await repository
            .publish(_bundle(), actorId: _actor);
        expect(publishReceipt.outcome, CollectionPublishOutcome.created);
        expect(publishReceipt.publishedAtUtc, isNotNull);
        expect(await repository.getActiveVersion('col-1'), isNotNull);

        // And replaying publish() again now correctly reports a publish
        // replay, not a review one.
        final CollectionPublishReceipt publishReplay = await repository
            .publish(_bundle(), actorId: _actor);
        expect(
          publishReplay.outcome,
          CollectionPublishOutcome.replayedIdempotentSuccess,
        );
      },
    );
  });

  group('Discover sink wiring', () {
    test('publish activates the sink with the freshly-active version', () async {
      final CollectionPublishReceipt receipt = await repository.publish(
        _bundle(),
        actorId: _actor,
      );

      expect(sink.activateCalls, hasLength(1));
      expect(sink.activateCalls.single.collectionId, 'col-1');
      expect(receipt.discoverSynced, isTrue);
    });

    test('a sink failure retries once, then reports discoverSynced: false '
        'without failing the publish', () async {
      sink.failNextActivations = 2; // exhausts publish()'s one retry
      final CollectionPublishReceipt receipt = await repository.publish(
        _bundle(),
        actorId: _actor,
      );

      expect(sink.activateCalls, hasLength(2)); // first try + one retry
      expect(receipt.outcome, CollectionPublishOutcome.created);
      expect(receipt.discoverSynced, isFalse);
    });

    test('a single transient sink failure recovers on the retry', () async {
      sink.failNextActivations = 1;
      final CollectionPublishReceipt receipt = await repository.publish(
        _bundle(),
        actorId: _actor,
      );

      expect(sink.activateCalls, hasLength(2));
      expect(receipt.discoverSynced, isTrue);
    });
  });

  group('removal-only', () {
    test('removes only the requested refs and re-syncs the sink', () async {
      final CollectionItemDraft item1 = CollectionItemDraft(
        id: 'item-1',
        ref: const CollectionObjectRef(
          objectId: 'p1',
          objectType: CollectionCatalogObjectType.place,
        ),
        snapshot: const CollectionItemSnapshotDraft(title: 'Place one'),
        sourceStatus: CollectionSourceStatus.ready,
        order: 0,
      );
      final CollectionItemDraft item2 = CollectionItemDraft(
        id: 'item-2',
        ref: const CollectionObjectRef(
          objectId: 'p2',
          objectType: CollectionCatalogObjectType.place,
        ),
        snapshot: const CollectionItemSnapshotDraft(title: 'Place two'),
        sourceStatus: CollectionSourceStatus.ready,
        order: 1,
      );
      final CollectionPublishReceipt published = await repository.publish(
        _bundle().copyWith(items: <CollectionItemDraft>[item1, item2]),
        actorId: _actor,
      );

      final CollectionPublishReceipt afterRemoval = await repository
          .removeItemsOnly(
            CollectionRemovalOnlyCommand(
              collectionId: 'col-1',
              baseVersionId: published.collectionVersionId,
              expectedBaseRevisionOrHash: published.collectionVersionId,
              removedItemRefs: <String>{item1.ref.stableKey},
              requestId: 'removal-1',
              actorId: _actor,
            ),
          );

      final PublishedCollectionVersion? active = await repository
          .getActiveVersion('col-1');
      expect(active!.bundle.items.map((i) => i.id), <String>['item-2']);
      expect(afterRemoval.discoverSynced, isTrue);
      expect(sink.activateCalls, hasLength(2)); // publish + removal
    });

    test('a stale expectedBaseRevisionOrHash is a revision conflict', () async {
      await repository.publish(_bundle(), actorId: _actor);
      expect(
        () => repository.removeItemsOnly(
          const CollectionRemovalOnlyCommand(
            collectionId: 'col-1',
            baseVersionId: 'v1',
            expectedBaseRevisionOrHash: 'stale-version',
            removedItemRefs: <String>{},
            requestId: 'removal-1',
            actorId: _actor,
          ),
        ),
        throwsA(
          isA<CollectionPublicationException>().having(
            (e) => e.failure,
            'failure',
            CollectionPublicationFailure.revisionConflict,
          ),
        ),
      );
    });
  });

  group('archive', () {
    test('deactivates the active version and calls sink.archive', () async {
      await repository.publish(_bundle(), actorId: _actor);
      final bool synced = await repository.archive('col-1', actorId: _actor);

      expect(synced, isTrue);
      expect(sink.archiveCalls, <String>['col-1']);
      expect(await repository.getActiveVersion('col-1'), isNull);
    });

    test('archiving a Collection with no active version never touches the '
        'sink and is trivially synced', () async {
      final bool synced = await repository.archive(
        'never-published',
        actorId: _actor,
      );
      expect(synced, isTrue);
      expect(sink.archiveCalls, isEmpty);
    });

    test('a sink.archive failure is retried once, then reported back — the '
        'local record stays archived either way', () async {
      await repository.publish(_bundle(), actorId: _actor);
      sink.failNextArchives = 5; // exceeds the retry budget
      final bool synced = await repository.archive('col-1', actorId: _actor);

      expect(synced, isFalse);
      expect(sink.archiveCalls, hasLength(2)); // one try + one retry
      expect(await repository.getActiveVersion('col-1'), isNull);
    });

    test(
      'a retried archive() after a sink failure re-attempts the sink '
      'instead of silently giving up — CLG-PST-01 review finding',
      () async {
        await repository.publish(_bundle(), actorId: _actor);
        sink.failNextArchives = 2; // exhausts the one-try-plus-one-retry budget
        final bool firstAttempt = await repository.archive(
          'col-1',
          actorId: _actor,
        );
        expect(firstAttempt, isFalse); // one try + one retry, both failed
        expect(sink.archiveCalls, hasLength(2));

        // The local record must already be archived (not deleted outright)
        // so this second call still has something to sync against.
        final bool secondAttempt = await repository.archive(
          'col-1',
          actorId: _actor,
        );
        expect(secondAttempt, isTrue);
        expect(sink.archiveCalls, hasLength(3)); // sink actually called again
      },
    );
  });

  group('moderation (submit / pending / decide)', () {
    test('submitForReview never touches the sink', () async {
      final CollectionPublishReceipt receipt = await repository
          .submitForReview(_bundle(), actorId: _actor);

      expect(receipt.outcome, CollectionPublishOutcome.pendingReview);
      expect(receipt.publishedAtUtc, isNull);
      expect(receipt.submittedAtUtc, isNotNull);
      expect(sink.activateCalls, isEmpty);
      expect(await repository.getActiveVersion('col-1'), isNull);
    });

    test(
      'replaying submitForReview stays pendingReview — it must never read '
      'back as a publish (the original review finding)',
      () async {
        final CollectionPublishReceipt first = await repository
            .submitForReview(_bundle(), actorId: _actor);
        final CollectionPublishReceipt replay = await repository
            .submitForReview(_bundle(), actorId: _actor);

        expect(first.outcome, CollectionPublishOutcome.pendingReview);
        expect(replay.outcome, CollectionPublishOutcome.pendingReview);
        expect(replay.publishedAtUtc, isNull);
        expect(await repository.getActiveVersion('col-1'), isNull);
      },
    );

    test('a pending request appears in pendingRequests until decided', () async {
      await repository.submitForReview(_bundle(), actorId: _actor);
      final requests = await repository.pendingRequests();
      expect(requests, hasLength(1));
      expect(requests.single.collectionId, 'col-1');
      expect(requests.single.submittedAsPublisher, _publisher);
      expect(requests.single.submittedByActorId, _actor);
      expect(requests.single.isPending, isTrue);

      await repository.decide(
        requestId: 'attempt-1',
        accept: true,
        decidedByActorId: 'moderator-1',
      );
      expect(await repository.pendingRequests(), isEmpty);
    });

    test('accepting activates the version through the sink and records the '
        'moderator', () async {
      await repository.submitForReview(_bundle(), actorId: _actor);
      final CollectionModerationDecisionResult result = await repository
          .decide(
            requestId: 'attempt-1',
            accept: true,
            decidedByActorId: 'moderator-1',
          );

      expect(
        result.request.decision!.outcome,
        CollectionModerationDecisionOutcome.accepted,
      );
      expect(result.request.decision!.decidedByActorId, 'moderator-1');
      expect(result.discoverSynced, isTrue);
      expect(sink.activateCalls, hasLength(1));
      expect(await repository.getActiveVersion('col-1'), isNotNull);
    });

    test('rejecting requires a reason code and never touches the sink', () async {
      await repository.submitForReview(_bundle(), actorId: _actor);

      expect(
        () => repository.decide(
          requestId: 'attempt-1',
          accept: false,
          decidedByActorId: 'moderator-1',
        ),
        throwsArgumentError,
      );

      final CollectionModerationDecisionResult result = await repository
          .decide(
            requestId: 'attempt-1',
            accept: false,
            decidedByActorId: 'moderator-1',
            rejectionReason: CollectionModerationRejectionReason.qualityIssue,
          );

      expect(
        result.request.decision!.outcome,
        CollectionModerationDecisionOutcome.rejected,
      );
      expect(
        result.request.decision!.rejectionReason,
        CollectionModerationRejectionReason.qualityIssue,
      );
      expect(sink.activateCalls, isEmpty);
      expect(await repository.getActiveVersion('col-1'), isNull);
    });

    test('a decision is sealed — deciding the same request twice is refused',
        () async {
      await repository.submitForReview(_bundle(), actorId: _actor);
      await repository.decide(
        requestId: 'attempt-1',
        accept: true,
        decidedByActorId: 'moderator-1',
      );

      expect(
        () => repository.decide(
          requestId: 'attempt-1',
          accept: true,
          decidedByActorId: 'moderator-1',
        ),
        throwsA(
          isA<CollectionPublicationException>().having(
            (e) => e.failure,
            'failure',
            CollectionPublicationFailure.idempotencyConflict,
          ),
        ),
      );
    });

    test('deciding an unknown request id is a not-found failure', () async {
      expect(
        () => repository.decide(
          requestId: 'missing',
          accept: true,
          decidedByActorId: 'moderator-1',
        ),
        throwsA(
          isA<CollectionPublicationException>().having(
            (e) => e.failure,
            'failure',
            CollectionPublicationFailure.notFound,
          ),
        ),
      );
    });
  });

  group('Create -> Discover integration (real adapter + real local store)', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('a direct publish is visible to Discover through the real sink '
        '+ port', () async {
      final PublishedCollectionDiscoveryLocalDataSource discoveryStore =
          PublishedCollectionDiscoveryLocalDataSource(
            const FlutterSecureStorage(),
          );
      final CollectionPublicationDiscoveryAdapter adapter =
          CollectionPublicationDiscoveryAdapter(discoveryStore);
      final CollectionPublicationLocalDatasource realDatasource =
          CollectionPublicationLocalDatasource(
            idGenerator: _FakeIdGenerator(),
            store: const SecureCollectionPublicationStore(
              FlutterSecureStorage(),
            ),
          );
      final CollectionPublicationRepositoryImpl realRepository =
          CollectionPublicationRepositoryImpl(
            datasource: realDatasource,
            sink: adapter,
          );

      expect(await adapter.loadActiveCollections(), isEmpty);

      // `PublishedCollectionDiscoveryEntity.isCoherent` requires at least
      // one item — the real adapter/store enforce this invariant, unlike
      // the `_RecordingSink` fake used by the tests above.
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
      await realRepository.publish(
        _bundle(
          collectionId: 'col-real',
        ).copyWith(items: <CollectionItemDraft>[item]),
        actorId: _actor,
      );

      final discovered = await adapter.loadActiveCollections();
      expect(discovered, hasLength(1));
      expect(discovered.single.collectionId, 'col-real');
      expect(discovered.single.title, 'A guide');

      await realRepository.archive('col-real', actorId: _actor);
      expect(await adapter.loadActiveCollections(), isEmpty);
    });
  });
}

class _FakeIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String generate() => 'gen-${_counter++}';
}

class _RecordingSink implements CollectionPublicationIndexSink {
  final List<PublishedCollectionVersion> activateCalls =
      <PublishedCollectionVersion>[];
  final List<String> archiveCalls = <String>[];
  int failNextActivations = 0;
  int failNextArchives = 0;

  @override
  Future<void> activate(PublishedCollectionVersion version) async {
    activateCalls.add(version);
    if (failNextActivations > 0) {
      failNextActivations--;
      throw StateError('simulated sink activation failure');
    }
  }

  @override
  Future<void> archive(String collectionId) async {
    archiveCalls.add(collectionId);
    if (failNextArchives > 0) {
      failNextArchives--;
      throw StateError('simulated sink archive failure');
    }
  }
}
