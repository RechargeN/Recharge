import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/collection_content_publication_composition.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/collection_content_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/data/repositories/catalog_collection_catalog_search_repository.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/collection_content_publication.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/collection_catalog_search_repository.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_collection_draft.dart';
import 'support/stand_backend.dart';

/// D3.4: the Create item picker over the real Catalog of the local
/// demo-recharge stand finds the published member Places; the user's own Create
/// Collection draft that references them goes through the real Content (with
/// Catalog-owned membership), Media and C2 moderation services: save (empty
/// draft, then the body), cover upload, submit, staff review (the C2 staff
/// script), owner publish and hide. A reference to an unknown object is
/// refused by the server. The draft is read back through the real Create
/// repository.
///
/// Limits: PC host run against the local Emulator started with
/// `RECHARGE_TEST_COLLECTION_MEMBERSHIP=true`; Media uses the existing fake
/// scanner/processor; staff authority is the test-only stand registry;
/// Collection authoring is enabled by `stand-seed.mjs collection seed`.
void main() {
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late Map<String, Object?> seeded;
  final runtimes = <String, Future<BookingTransportRuntime>>{};

  Future<BookingTransportRuntime> runtimeFor(
    String label,
  ) => runtimes.putIfAbsent(label, () async {
    final binding = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    final sessions = FileSessionStore(File('${temp.path}/session-$label.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-$label'),
      sessions: sessions,
      installations: FixedInstallationId('d34-local-installation-$label'),
      supportDirectory: () async =>
          Directory('${temp.path}/support-$label').create(recursive: true),
    ).create();
    if (await sessions.read() == null) {
      try {
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
      } on BookingCallableFailure catch (error) {
        fail('establish failed for $label with ${error.code}');
      }
    }
    return runtime;
  });

  CollectionPublicationTestEntryGuard guard() =>
      CollectionPublicationTestEntryGuard(
        flag: true,
        releaseMode: false,
        binding: BookingBackendBindingController(
          emulatorBase: StandBackend.functionsBase,
          releaseMode: false,
          initial: BackendBindingMode.testBackend,
        ),
      );

  Future<CatalogCollectionCatalogSearchRepository> pickerFor(
    String label,
  ) async {
    final runtime = await runtimeFor(label);
    return CatalogCollectionCatalogSearchRepository(
      query: collectionCatalogQueryFor(
        guard: guard(),
        runtime: () async => runtime,
      ),
      marketId: 'LV',
    );
  }

  Future<CollectionContentPublicationController> controllerFor(
    String label,
    CreateDraftEntity draft,
  ) async {
    final repository = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );
    await repository.saveDraft('user-$label', draft);
    final runtime = await runtimeFor(label);
    return collectionContentPublicationControllerFor(
      accountId: 'user-$label',
      port: runtime.port!,
      guard: guard(),
      drafts: CreateRepositoryCollectionDraftSource(repository, 'user-$label'),
      membership: await pickerFor(label),
      journalFile: File('${temp.path}/journal-$label.json'),
    );
  }

  List<Map<String, Object?>> members() =>
      (seeded['members']! as List<Object?>).cast<Map<String, Object?>>();

  setUpAll(() async {
    if (stand == null) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('d34-local-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
    // Idempotent: the D3.4 gate has seeded it already.
    await stand.collectionSeed();
    seeded = await stand.collectionManifest();
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'the picker finds the published member Places; the Catalog answers exact statuses',
    () async {
      final picker = await pickerFor('creator');
      final Set<String> found = <String>{};
      for (final Map<String, Object?> member in members()) {
        final results = await picker.search(
          CollectionCatalogSearchQuery(
            text: member['title']! as String,
            allowedTypes: CollectionCatalogObjectType.values.toSet(),
            marketCityId: 'riga',
          ),
        );
        found.addAll(
          results.map(
            (CollectionCatalogSearchResult item) => item.ref.objectId,
          ),
        );
      }
      expect(
        found,
        containsAll(members().map((member) => member['contentId'])),
      );
      final first = CollectionObjectRef(
        objectId: members().first['contentId']! as String,
        objectType: CollectionCatalogObjectType.place,
      );
      expect((await picker.statusOf(first)).status, 'eligible');
      // The Collection itself is never a member; nor a Place asked as Rental.
      expect(
        (await picker.statusOf(
          CollectionObjectRef(
            objectId: seeded['contentId']! as String,
            objectType: CollectionCatalogObjectType.place,
          ),
        )).status,
        'forbidden',
      );
      expect(
        (await picker.statusOf(
          CollectionObjectRef(
            objectId: first.objectId,
            objectType: CollectionCatalogObjectType.rental,
          ),
        )).status,
        'forbidden',
      );
      expect(
        (await picker.statusOf(
          CollectionObjectRef(
            objectId: const Uuid().v4(),
            objectType: CollectionCatalogObjectType.place,
          ),
        )).status,
        'unknown',
      );
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the Creator publishes the Create Collection draft through Content, Media and review',
    () async {
      final picker = await pickerFor('creator');
      // The draft references exactly what the picker resolved.
      final resolved = await picker.resolve(<CollectionObjectRef>[
        for (final member in members())
          CollectionObjectRef(
            objectId: member['contentId']! as String,
            objectType: CollectionCatalogObjectType.place,
          ),
      ]);
      expect(resolved, hasLength(3));
      final draft = userCollectionDraft(
        pageId: seeded['pageId']! as String,
        members: <CollectionFixtureMember>[
          for (final result in resolved.values)
            CollectionFixtureMember(
              objectId: result.ref.objectId,
              title: result.snapshot.title,
            ),
        ],
        coverPath: cover.path,
        localId: 'loc_d34_${const Uuid().v4()}',
        title: 'Quiet corners (controller path)',
      );
      final c = await controllerFor('creator', draft);
      await c.load();
      expect(c.state.draftTitle, draft.title);
      expect(
        c.state.members.map((CollectionMemberStatus item) => item.status),
        <String>['eligible', 'eligible', 'eligible'],
      );

      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.record?.bodySaved, isTrue);
      // Before the cover is uploaded the server refuses the local id.
      await c.submit();
      expect(c.state.message, 'validation_failed');

      await c.uploadMedia();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.record?.attachments, hasLength(1));

      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.latestSubmissionState, 'under_review');
      await c.publish();
      expect(c.state.message, 'moderation_required');

      final approved = await stand!.moderate(<String>[
        'approve',
        c.state.status!.latestSubmissionId!,
        '--reason',
        'd3.4 local: the Collection is fine',
      ]);
      expect(approved.exitCode, 0, reason: '${approved.json}');
      await c.refresh();
      expect(c.state.status?.latestSubmissionState, 'approved_for_publication');
      await c.publish();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.visibility, 'visible');
      expect(c.state.myObjects.single.status?.visibility, 'visible');

      await c.hide();
      expect(c.state.status?.visibility, 'withdrawn');
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'a reference to an unknown object is refused by the server, not by the client',
    () async {
      final draft = userCollectionDraft(
        pageId: seeded['pageId']! as String,
        members: <CollectionFixtureMember>[
          for (final member in members().take(2))
            CollectionFixtureMember(objectId: member['contentId']! as String),
          CollectionFixtureMember(objectId: const Uuid().v4()),
        ],
        coverPath: cover.path,
        localId: 'loc_d34_unknown_${const Uuid().v4()}',
      );
      final c = await controllerFor('creator', draft);
      await c.load();
      expect(c.state.members.last.status, 'unknown');
      await c.save();
      await c.uploadMedia();
      expect(c.state.message, isNull, reason: c.state.message);
      await c.submit();
      expect(c.state.message, 'validation_failed');
      expect(c.state.status?.latestSubmissionState, isNull);
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the seeded Collection of the stand is a Content publication (manifest ids)',
    () async {
      final runtime = await runtimeFor('creator');
      final gateway = FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter(runtime.port!),
        gate: guard(),
        typeId: 'collection',
      );
      final status = await gateway.status(seeded['contentId']! as String);
      expect(status.visibility, 'visible');
      expect(status.currentPublishedRevisionId, seeded['publishedRevisionId']);
      expect(status.latestSubmissionState, 'published');
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
