import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/collection_create_coordinator.dart';
import 'package:recharge/features/create/application/state/collection_create_state.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/collection_publication_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/collection_moderation_request.dart';
import 'package:recharge/features/create/domain/entities/collection_publication_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/location_search_suggestion.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/collection_catalog_search_repository.dart';
import 'package:recharge/features/create/domain/repositories/collection_publication_index_sink.dart';
import 'package:recharge/features/create/domain/repositories/collection_publication_repository.dart';
import 'package:recharge/features/create/domain/repositories/location_search_repository.dart';

const _publisher = PublisherRef(type: PublisherType.user, id: 'u1');

List<CollectionItemDraft> _threeReadyItems() => List<CollectionItemDraft>.generate(
  3,
  (i) => CollectionItemDraft(
    id: 'item-$i',
    ref: CollectionObjectRef(
      objectId: 'p$i',
      objectType: CollectionCatalogObjectType.place,
    ),
    snapshot: CollectionItemSnapshotDraft(title: 'Place $i'),
    sourceStatus: CollectionSourceStatus.ready,
    order: i,
  ),
);

CollectionDraftData _publishableData() {
  return CollectionDraftData.defaults(publisherRef: _publisher).copyWith(
    areaLabel: 'Riga',
    items: _threeReadyItems(),
    compositionReview: CollectionCompositionReview(
      draftRevision: 0,
      reviewedAtUtc: DateTime.utc(2026),
      acknowledgedUnavailableStableKeys: const <String>{},
    ),
  );
}

CreateDraftEntity _draft({required String id, CollectionDraftData? data}) {
  return CreateDraftEntity.defaults(
    organizerId: 'u1',
    organizerEmail: 'e@example.com',
    organizerName: 'n',
  ).copyWith(
    id: id,
    objectType: CreateObjectType.collection,
    title: 'A guide',
    collectionData: data ?? _publishableData(),
  );
}

void main() {
  late CollectionPublicationLocalDatasource datasource;
  late _NoopSink sink;
  late CollectionPublicationRepositoryImpl publicationRepository;
  late CollectionCreateCoordinator coordinator;

  setUp(() {
    datasource = CollectionPublicationLocalDatasource(
      idGenerator: _SequentialIdGenerator(),
    );
    sink = _NoopSink();
    publicationRepository = CollectionPublicationRepositoryImpl(
      datasource: datasource,
      sink: sink,
    );
    coordinator = CollectionCreateCoordinator(
      idGenerator: _SequentialIdGenerator(),
      catalogSearchRepository: _NoopCatalogSearchRepository(),
      publicationRepository: publicationRepository,
      locationSearchRepository: _NoopLocationSearchRepository(),
    );
  });

  group('publish idempotency', () {
    test('two publish(direct:true) calls with no mutation between them '
        'replay the same write, never a second Collection', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_new1'));

      final CollectionPublishReceipt first = await coordinator.publish(
        direct: true,
        actorId: 'user-1',
      );
      final CollectionPublishReceipt second = await coordinator.publish(
        direct: true,
        actorId: 'user-1',
      );

      expect(first.outcome, CollectionPublishOutcome.created);
      expect(second.outcome, CollectionPublishOutcome.replayedIdempotentSuccess);
      expect(second.collectionId, first.collectionId);
      expect(second.collectionVersionId, first.collectionVersionId);
    });

    test('a real mutation between two publishes produces a genuinely new '
        'version, not a conflict', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_new2'));
      final CollectionPublishReceipt first = await coordinator.publish(
        direct: true,
        actorId: 'user-1',
      );

      coordinator.setBudgetIndicator(CollectionBudgetTier.low);
      coordinator.acknowledgeCompositionReview();
      final CollectionPublishReceipt second = await coordinator.publish(
        direct: true,
        actorId: 'user-1',
      );

      expect(second.outcome, CollectionPublishOutcome.created);
      expect(second.collectionVersionId, isNot(first.collectionVersionId));
      expect(second.collectionId, first.collectionId); // same Collection
    });
  });

  group('loc_* -> permanent id fixup', () {
    test('a temporary draft id becomes the minted permanent id after '
        'publish, and stays that way on replay', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_temp'));
      expect(coordinator.state.createDraft.id, 'loc_temp');

      final CollectionPublishReceipt receipt = await coordinator.publish(
        direct: true,
        actorId: 'user-1',
      );

      expect(coordinator.state.createDraft.id, receipt.collectionId);
      expect(coordinator.state.createDraft.id, isNot(startsWith('loc_')));

      await coordinator.publish(direct: true, actorId: 'user-1'); // replay must not re-mint
      expect(coordinator.state.createDraft.id, receipt.collectionId);
    });

    test('a draft that already has a permanent id keeps it', () async {
      coordinator.initialize(createDraft: _draft(id: 'already-permanent'));
      final CollectionPublishReceipt receipt = await coordinator.publish(
        direct: true,
        actorId: 'user-1',
      );
      expect(receipt.collectionId, 'already-permanent');
      expect(coordinator.state.createDraft.id, 'already-permanent');
    });
  });

  group('direct vs review branching', () {
    test('direct:true activates immediately (created, publishedAtUtc set)', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_direct'));
      final CollectionPublishReceipt receipt = await coordinator.publish(
        direct: true,
        actorId: 'user-1',
      );

      expect(receipt.outcome, CollectionPublishOutcome.created);
      expect(receipt.publishedAtUtc, isNotNull);
      expect(receipt.submittedAtUtc, isNull);
      expect(coordinator.state.status, CollectionCreateStatus.published);
    });

    test('direct:false submits for review without activating', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_review'));
      final CollectionPublishReceipt receipt = await coordinator.publish(
        direct: false,
        actorId: 'user-1',
      );

      expect(receipt.outcome, CollectionPublishOutcome.pendingReview);
      expect(receipt.submittedAtUtc, isNotNull);
      expect(receipt.publishedAtUtc, isNull);
      expect(coordinator.state.status, CollectionCreateStatus.submittedForReview);
      expect(sink.activateCalls, isEmpty);
    });

    test('a still-blocking validation issue throws before any write', () async {
      coordinator.initialize(
        createDraft: _draft(id: 'loc_invalid', data: CollectionDraftData.defaults(publisherRef: _publisher)),
      );
      expect(
        () => coordinator.publish(direct: true, actorId: 'user-1'),
        throwsA(isA<StateError>()),
      );
      expect(coordinator.state.status, CollectionCreateStatus.editing);
    });
  });

  group('archive', () {
    test('never called on a Collection that was never published (loc_* id)', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_unpublished'));
      final bool synced = await coordinator.archive();
      expect(synced, isTrue); // trivially in sync — nothing to archive
      expect(sink.archiveCalls, isEmpty);
    });

    test('archives the permanent Collection after a successful publish', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_toarchive'));
      final CollectionPublishReceipt receipt = await coordinator.publish(
        direct: true,
        actorId: 'user-1',
      );
      final bool synced = await coordinator.archive();
      expect(synced, isTrue);
      expect(sink.archiveCalls, <String>[receipt.collectionId]);
    });
  });

  group('moderation delegation', () {
    test('pendingModerationRequests and decideModerationRequest delegate '
        'straight to the repository, accept activates', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_moderate'));
      await coordinator.publish(direct: false, actorId: 'user-1');
      final List<CollectionModerationRequest> pending = await coordinator
          .pendingModerationRequests();
      expect(pending, hasLength(1));

      final CollectionModerationDecisionResult result = await coordinator
          .decideModerationRequest(
            requestId: pending.single.requestId,
            accept: true,
            decidedByActorId: 'moderator-1',
          );

      expect(
        result.request.decision!.outcome,
        CollectionModerationDecisionOutcome.accepted,
      );
      expect(result.request.decision!.decidedByActorId, 'moderator-1');
      expect(result.request.submittedByActorId, 'user-1');
      expect(await coordinator.pendingModerationRequests(), isEmpty);
      expect(sink.activateCalls, hasLength(1));
    });

    test('reject requires a reason code and never activates', () async {
      coordinator.initialize(createDraft: _draft(id: 'loc_moderate_reject'));
      await coordinator.publish(direct: false, actorId: 'user-1');
      final List<CollectionModerationRequest> pending = await coordinator
          .pendingModerationRequests();

      final CollectionModerationDecisionResult result = await coordinator
          .decideModerationRequest(
            requestId: pending.single.requestId,
            accept: false,
            decidedByActorId: 'moderator-1',
            rejectionReason:
                CollectionModerationRejectionReason.incompleteSubmission,
          );

      expect(
        result.request.decision!.outcome,
        CollectionModerationDecisionOutcome.rejected,
      );
      expect(sink.activateCalls, isEmpty);
    });
  });
}

class _SequentialIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String generate() => 'gen-${_counter++}';
}

class _NoopSink implements CollectionPublicationIndexSink {
  final List<PublishedCollectionVersion> activateCalls =
      <PublishedCollectionVersion>[];
  final List<String> archiveCalls = <String>[];

  @override
  Future<void> activate(PublishedCollectionVersion version) async {
    activateCalls.add(version);
  }

  @override
  Future<void> archive(String collectionId) async {
    archiveCalls.add(collectionId);
  }
}

class _NoopCatalogSearchRepository implements CollectionCatalogSearchRepository {
  @override
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  ) async => const <CollectionCatalogSearchResult>[];

  @override
  Future<Map<String, CollectionCatalogSearchResult>> resolve(
    List<CollectionObjectRef> refs,
  ) async => const <String, CollectionCatalogSearchResult>{};
}

class _NoopLocationSearchRepository implements LocationSearchRepository {
  @override
  Future<List<LocationSearchSuggestion>> search(
    String query, {
    required String marketCityId,
  }) async => const <LocationSearchSuggestion>[];

  @override
  Future<LocationSearchResolution> resolve(String suggestionId) {
    throw UnimplementedError();
  }
}
