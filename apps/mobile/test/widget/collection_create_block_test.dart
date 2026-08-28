import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/collection_create_config.dart';
import 'package:recharge/features/create/application/collection_create_coordinator.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/data/datasources/collection_publication_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/collection_publication_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/location_search_suggestion.dart';
import 'package:recharge/features/create/domain/entities/collection_publication_data.dart';
import 'package:recharge/features/create/domain/repositories/collection_catalog_search_repository.dart';
import 'package:recharge/features/create/domain/repositories/collection_publication_index_sink.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/location_search_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/collection_create_block.dart';

import '../support/event_create_test_support.dart';
import 'widget_test_viewport.dart';

CollectionCreateCoordinator _buildCoordinator() {
  return CollectionCreateCoordinator(
    idGenerator: _SequentialIdGenerator(),
    catalogSearchRepository: _FakeCatalogSearchRepository(),
    publicationRepository: CollectionPublicationRepositoryImpl(
      datasource: CollectionPublicationLocalDatasource(
        idGenerator: _SequentialIdGenerator(),
      ),
      sink: _NoopSink(),
    ),
    locationSearchRepository: _FakeLocationSearchRepository(),
  );
}

void main() {
  late _FakeCreateRepository repository;
  late CreateController controller;
  late CollectionCreateCoordinator coordinator;

  setUp(() {
    repository = _FakeCreateRepository();
    coordinator = _buildCoordinator();
    controller = CreateController(
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
      collectionCreateConfig: const CollectionCreateRuntimeConfig(
        collectionPublishingEnabled: true,
      ),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  Widget app() {
    return ProviderScope(
      overrides: <Override>[
        collectionCreateCoordinatorProvider.overrideWith((ref) => coordinator),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) {
                return CollectionCreateBlock(
                  controller: controller,
                  state: controller.state,
                  onPublished: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  fullPageTestWidgets(
    'five-step flow: basics, add three items, curator notes, publish',
    (WidgetTester tester) async {
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
        capabilities: const <String>['create.collection', 'submit.collection'],
      );
      controller.setObjectType(CreateObjectType.collection);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Step 0 — Basics & media.
      expect(find.text('Basics & media'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'A Riga guide');
      await tester.enterText(find.byType(TextField).at(1), 'A short pitch.');
      await tester.enterText(find.byType(TextField).at(2), 'Riga');
      await tester.pumpAndSettle();
      expect(controller.state.draft.title, 'A Riga guide');

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1 — Items, via the extracted ItemsPickerSection widget.
      expect(find.text('Items'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('Cafe One'), findsOneWidget);
      expect(find.text('Cafe Two'), findsOneWidget);
      expect(find.text('Cafe Three'), findsOneWidget);

      await tester.tap(find.text('Cafe One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cafe Two'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cafe Three'));
      await tester.pumpAndSettle();

      expect(
        controller.collectionCreateState?.collectionData.items,
        hasLength(3),
      );
      expect(find.text('In this Collection (3)'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2 — Curator notes, via the extracted
      // CollectionCuratorNotesSection widget.
      expect(find.text('Curator notes'), findsOneWidget);
      expect(find.text('Cafe One'), findsOneWidget);
      expect(find.text('Cafe Two'), findsOneWidget);
      expect(find.text('Cafe Three'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3 — Budget & publisher.
      expect(find.text('Budget & publisher'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 4 — Preview & publish.
      expect(find.text('Preview & publish'), findsOneWidget);
      await tester.tap(find.text('Acknowledge composition'));
      await tester.pumpAndSettle();
      expect(find.text('Composition reviewed'), findsOneWidget);

      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      expect(controller.state.message, contains('Collection отправлен на проверку.'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders without overflow on a 360dp phone viewport',
    (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(360, 2200)
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
        capabilities: const <String>['create.collection'],
      );
      controller.setObjectType(CreateObjectType.collection);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Basics & media'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // setObjectType() schedules CreateController's autosave debounce
      // timer (~700ms) — drain it before the test ends, or the framework
      // flags a pending Timer after the widget tree is disposed.
      await tester.pump(const Duration(milliseconds: 800));
    },
  );
}

class _SequentialIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String generate() => 'gen-${_counter++}';
}

class _NoopSink implements CollectionPublicationIndexSink {
  @override
  Future<void> activate(PublishedCollectionVersion version) async {}

  @override
  Future<void> archive(String collectionId) async {}
}

class _FakeCatalogSearchRepository implements CollectionCatalogSearchRepository {
  static final List<CollectionCatalogSearchResult> _fixtures =
      <CollectionCatalogSearchResult>[
        _result('cafe-1', 'Cafe One'),
        _result('cafe-2', 'Cafe Two'),
        _result('cafe-3', 'Cafe Three'),
      ];

  static CollectionCatalogSearchResult _result(String id, String title) {
    return CollectionCatalogSearchResult(
      ref: CollectionObjectRef(
        objectId: id,
        objectType: CollectionCatalogObjectType.place,
      ),
      snapshot: CollectionItemSnapshotDraft(title: title),
    );
  }

  @override
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  ) async {
    return _fixtures
        .where((r) => !query.excludeRefs.contains(r.ref))
        .toList(growable: false);
  }

  @override
  Future<Map<String, CollectionCatalogSearchResult>> resolve(
    List<CollectionObjectRef> refs,
  ) async {
    return <String, CollectionCatalogSearchResult>{
      for (final CollectionCatalogSearchResult r in _fixtures)
        r.ref.stableKey: r,
    };
  }
}

class _FakeLocationSearchRepository implements LocationSearchRepository {
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
