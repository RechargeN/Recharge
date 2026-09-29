import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/collection_create_config.dart';
import 'package:recharge/features/create/application/collection_create_coordinator.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/state/collection_create_state.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_local_datasource.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_store.dart';
import 'package:recharge/features/create/data/repositories/collection_publication_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/collection_publication_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/location_search_suggestion.dart';
import 'package:recharge/features/create/domain/repositories/collection_catalog_search_repository.dart';
import 'package:recharge/features/create/domain/repositories/collection_publication_index_sink.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/location_search_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../support/event_create_test_support.dart';

CollectionCreateCoordinator _buildCoordinator({
  CollectionCreateRuntimeConfig config = const CollectionCreateRuntimeConfig(),
  required _RecordingSink sink,
}) {
  return CollectionCreateCoordinator(
    idGenerator: _SequentialIdGenerator(),
    catalogSearchRepository: _NoopCatalogSearchRepository(),
    publicationRepository: CollectionPublicationRepositoryImpl(
      datasource: CollectionPublicationLocalDatasource(
        idGenerator: _SequentialIdGenerator(),
        store: const SecureCollectionPublicationStore(FlutterSecureStorage()),
      ),
      sink: sink,
    ),
    locationSearchRepository: _NoopLocationSearchRepository(),
    config: config,
  );
}

CollectionCatalogSearchResult _catalogItem(String id) {
  return CollectionCatalogSearchResult(
    ref: CollectionObjectRef(
      objectId: id,
      objectType: CollectionCatalogObjectType.place,
    ),
    snapshot: CollectionItemSnapshotDraft(title: 'Place $id'),
  );
}

/// Builds a valid Collection through the same public commands the UI uses
/// (not by constructing `CollectionDraftData` directly) — exercises the
/// full attach -> mutate -> acknowledge -> publish path end to end.
void _fillPublishableCollection(CreateController controller) {
  controller.updateTitle('A guide');
  controller.setCollectionAreaLabel('Riga');
  controller.addCollectionItem(_catalogItem('p1'));
  controller.addCollectionItem(_catalogItem('p2'));
  controller.addCollectionItem(_catalogItem('p3'));
  controller.acknowledgeCollectionCompositionReview();
}

void main() {
  late _FakeCreateRepository repository;
  late _RecordingSink sink;

  CreateController buildController({
    CollectionCreateRuntimeConfig collectionCreateConfig =
        const CollectionCreateRuntimeConfig(),
  }) {
    return CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
      runtimeDefaults: const CreateRuntimeDefaults(
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      ),
      collectionCreateConfig: collectionCreateConfig,
    );
  }

  setUp(() {
    // CLG-PST-01: each fresh CollectionPublicationLocalDatasource built by
    // _buildCoordinator() below shares the same mock FlutterSecureStorage
    // backend across the whole process — reset it per test so one test's
    // Collection data can never leak into another's.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    repository = _FakeCreateRepository();
    sink = _RecordingSink();
  });

  test('collectionCreateEnabled:false keeps the Hub-level create gate '
      'fail-closed — attach is refused even with the capability', () async {
    final controller = buildController(
      collectionCreateConfig: const CollectionCreateRuntimeConfig(
        collectionCreateEnabled: false,
      ),
    );
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
      capabilities: const <String>['create.collection'],
    );
    controller.setObjectType(CreateObjectType.collection);

    controller.attachCollectionCoordinator(_buildCoordinator(sink: sink));

    expect(controller.collectionCreateState, isNull);
    controller.dispose();
  });

  test('missing create.collection refuses both setObjectType and attach', () async {
    final controller = buildController();
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
      capabilities: const <String>[],
    );

    controller.setObjectType(CreateObjectType.collection);
    expect(controller.state.draft.objectType, isNot(CreateObjectType.collection));
    expect(controller.state.message, contains('create.collection'));

    controller.attachCollectionCoordinator(_buildCoordinator(sink: sink));
    expect(controller.collectionCreateState, isNull);
    controller.dispose();
  });

  test('collectionPublishingEnabled:false blocks publish independently of '
      'capability — coordinator.publish is never reached', () async {
    final controller = buildController(
      collectionCreateConfig: const CollectionCreateRuntimeConfig(
        collectionPublishingEnabled: false,
      ),
    );
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
      capabilities: const <String>['create.collection', 'publish.collection.direct'],
    );
    controller.setObjectType(CreateObjectType.collection);
    controller.attachCollectionCoordinator(_buildCoordinator(sink: sink));
    _fillPublishableCollection(controller);

    final bool published = await controller.publishCollection();

    expect(published, isFalse);
    expect(controller.state.message, contains('временно отключена'));
    expect(sink.activateCalls, isEmpty);
    controller.dispose();
  });

  test(
    'the real default composition (no config override at all — the exact '
    'shape service_locator.dart registers) allows publish, now that '
    'CollectionCreateRuntimeConfig\'s own default enables it (CLG-PST-02)',
    () async {
      final controller = buildController(); // no collectionCreateConfig arg
      await controller.ensureLoaded(
        userId: 'u1',
        organizerEmail: 'e@example.com',
        organizerName: 'n',
        capabilities: const <String>[
          'create.collection',
          'publish.collection.direct',
        ],
      );
      controller.setObjectType(CreateObjectType.collection);
      controller.attachCollectionCoordinator(_buildCoordinator(sink: sink));
      _fillPublishableCollection(controller);

      final bool published = await controller.publishCollection();

      expect(published, isTrue);
      expect(
        controller.collectionCreateState?.status,
        CollectionCreateStatus.published,
      );
      expect(sink.activateCalls, hasLength(1));
      controller.dispose();
    },
  );

  test('submit.collection without publish.collection.direct always takes '
      'the review path, never activates the sink', () async {
    final controller = buildController(
      collectionCreateConfig: const CollectionCreateRuntimeConfig(
        collectionPublishingEnabled: true,
      ),
    );
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
      capabilities: const <String>['create.collection', 'submit.collection'],
    );
    controller.setObjectType(CreateObjectType.collection);
    controller.attachCollectionCoordinator(_buildCoordinator(sink: sink));
    _fillPublishableCollection(controller);

    final bool published = await controller.publishCollection();

    expect(published, isTrue);
    expect(controller.state.message, contains('проверку'));
    expect(
      controller.collectionCreateState?.status,
      CollectionCreateStatus.submittedForReview,
    );
    expect(sink.activateCalls, isEmpty);
    controller.dispose();
  });

  test('publish.collection.direct activates immediately', () async {
    final controller = buildController(
      collectionCreateConfig: const CollectionCreateRuntimeConfig(
        collectionPublishingEnabled: true,
      ),
    );
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
      capabilities: const <String>[
        'create.collection',
        'publish.collection.direct',
      ],
    );
    controller.setObjectType(CreateObjectType.collection);
    controller.attachCollectionCoordinator(_buildCoordinator(sink: sink));
    _fillPublishableCollection(controller);

    final bool published = await controller.publishCollection();

    expect(published, isTrue);
    expect(
      controller.collectionCreateState?.status,
      CollectionCreateStatus.published,
    );
    expect(sink.activateCalls, hasLength(1));
    controller.dispose();
  });

  test('neither submit.collection nor publish.collection.direct refuses '
      'to publish at all', () async {
    final controller = buildController(
      collectionCreateConfig: const CollectionCreateRuntimeConfig(
        collectionPublishingEnabled: true,
      ),
    );
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
      capabilities: const <String>['create.collection'],
    );
    controller.setObjectType(CreateObjectType.collection);
    controller.attachCollectionCoordinator(_buildCoordinator(sink: sink));
    _fillPublishableCollection(controller);

    final bool published = await controller.publishCollection();

    expect(published, isFalse);
    expect(sink.activateCalls, isEmpty);
    controller.dispose();
  });

  test('archiveCollection/removeCollectionItemsFromActiveVersion/'
      'decideCollectionModerationRequest each re-check their own '
      'capability, independent of create.collection', () async {
    final controller = buildController(
      collectionCreateConfig: const CollectionCreateRuntimeConfig(
        collectionPublishingEnabled: true,
      ),
    );
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
      capabilities: const <String>[
        'create.collection',
        'publish.collection.direct',
      ], // deliberately missing archive/manage/moderate.collection
    );
    controller.setObjectType(CreateObjectType.collection);
    controller.attachCollectionCoordinator(_buildCoordinator(sink: sink));
    _fillPublishableCollection(controller);
    await controller.publishCollection();

    expect(await controller.archiveCollection(), isFalse);
    expect(
      await controller.removeCollectionItemsFromActiveVersion(<String>{'x'}),
      isFalse,
    );
    expect(
      await controller.decideCollectionModerationRequest(
        requestId: 'whatever',
        accept: true,
      ),
      isFalse,
    );
    expect(sink.archiveCalls, isEmpty);
    controller.dispose();
  });
}

class _SequentialIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String generate() => 'gen-${_counter++}';
}

class _RecordingSink implements CollectionPublicationIndexSink {
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

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeCreateRepository implements CreateRepository {
  CreateDraftEntity? _stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => _stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    _stored = draft;
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    _stored = draft;
    return draft;
  }
}
