import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/collection_content_publication_composition.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/media_composition.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/collection_catalog_search_repository.dart';

/// D3.4 §5.1: the Collection test entry is its own default-off switch with the
/// same four conditions as the other entries, and it closes the route, the
/// Create picker over the Catalog, every Content command and every Media
/// upload.
void main() {
  final Uri base = Uri.parse(
    'http://127.0.0.1:5001/demo-recharge/europe-west1',
  );

  CollectionPublicationTestEntryGuard guard({
    bool flag = true,
    bool release = false,
    BackendBindingMode mode = BackendBindingMode.testBackend,
    Uri? emulatorBase,
  }) => CollectionPublicationTestEntryGuard(
    flag: flag,
    releaseMode: release,
    binding: BookingBackendBindingController(
      emulatorBase: emulatorBase ?? base,
      releaseMode: release,
      initial: mode,
    ),
  );

  test('allowed only when every condition holds at once', () {
    expect(guard().allowed, isTrue);
    expect(guard(flag: false).allowed, isFalse);
    expect(guard(release: true).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.localOnly).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.disabled).allowed, isFalse);
    expect(
      guard(
        emulatorBase: Uri.parse(
          'http://10.0.2.2:5001/demo-recharge/europe-west1',
        ),
      ).allowed,
      isFalse,
    );
    expect(
      guard(
        emulatorBase: Uri.parse(
          'http://127.0.0.1:5001/real-project/europe-west1',
        ),
      ).allowed,
      isFalse,
    );
  });

  test(
    'the compile-time define is off unless set',
    () {
      expect(collectionPublicationTestEntryDefined, isFalse);
      expect(
        CollectionPublicationTestEntryGuard.fromEnvironment(
          BookingBackendBindingController(
            emulatorBase: base,
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          ),
        ).allowed,
        isFalse,
      );
    },
    skip: collectionPublicationTestEntryDefined
        ? 'run with the define on'
        : false,
  );

  test('the route redirect refuses unless the guard allows', () {
    expect(collectionPublicationTestEntryRedirect(null, fallback: '/x'), '/x');
    expect(
      collectionPublicationTestEntryRedirect(
        guard(flag: false),
        fallback: '/x',
      ),
      '/x',
    );
    expect(
      collectionPublicationTestEntryRedirect(guard(), fallback: '/x'),
      isNull,
    );
  });

  test(
    'neither Content, Media nor the Catalog is reached when the gate denies',
    () async {
      final _CountingPort port = _CountingPort();
      final CollectionPublicationTestEntryGuard closed = guard(flag: false);
      final FunctionsEventPublicationGateway gateway =
          FunctionsEventPublicationGateway(
            port: BookingPortContentAdapter(port),
            gate: closed,
            typeId: 'collection',
          );
      await expectLater(gateway.status('content'), throwsStateError);
      await expectLater(
        gateway.createDraft(
          publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
          marketId: 'LV',
          body: const <String, Object?>{},
          idempotencyKey: 'key-00000001',
        ),
        throwsStateError,
      );
      final MediaEventCoverUploader uploader = MediaEventCoverUploader(
        mediaUploadGatewayFor(port: port, gate: closed),
      );
      await expectLater(
        uploader.upload(
          intentId: 'cc088011-4f89-400c-b2cd-ebbf22fbcdc8',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          declaredMediaType: 'image/png',
          publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
          contentId: 'content',
        ),
        throwsA(anything),
      );
      int runtimes = 0;
      final query = collectionCatalogQueryFor(
        guard: closed,
        runtime: () {
          runtimes += 1;
          return Future<BookingTransportRuntime>.error(StateError('unused'));
        },
      );
      await expectLater(query(<String, Object?>{}), throwsStateError);
      expect(runtimes, 0);
      expect(port.calls, 0, reason: 'nothing may reach the transport');
    },
  );

  test(
    'the Create picker reads the server Catalog only while the entry is allowed',
    () async {
      final _Picker server = _Picker('server');
      final _Picker local = _Picker('local');
      final BookingBackendBindingController binding =
          BookingBackendBindingController(
            emulatorBase: base,
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          );
      final CollectionPublicationTestEntryGuard open =
          CollectionPublicationTestEntryGuard(
            flag: true,
            releaseMode: false,
            binding: binding,
          );
      final TestEntryCollectionCatalogSearchRepository picker =
          TestEntryCollectionCatalogSearchRepository(
            guard: open,
            server: server,
            local: local,
          );
      const CollectionCatalogSearchQuery query = CollectionCatalogSearchQuery(
        text: 'park',
        allowedTypes: <CollectionCatalogObjectType>{
          CollectionCatalogObjectType.place,
        },
        marketCityId: 'riga',
      );
      await picker.search(query);
      await picker.resolve(const <CollectionObjectRef>[]);
      expect(server.calls, 2);
      expect(local.calls, 0);
      final TestEntryCollectionCatalogSearchRepository closedPicker =
          TestEntryCollectionCatalogSearchRepository(
            guard: guard(flag: false),
            server: server,
            local: local,
          );
      await closedPicker.search(query);
      await closedPicker.resolve(const <CollectionObjectRef>[]);
      expect(
        server.calls,
        2,
        reason: 'a closed entry never reaches the Catalog',
      );
      expect(local.calls, 2);
    },
  );
}

final class _Picker implements CollectionCatalogSearchRepository {
  _Picker(this.name);

  final String name;
  int calls = 0;

  @override
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  ) async {
    calls += 1;
    return const <CollectionCatalogSearchResult>[];
  }

  @override
  Future<Map<String, CollectionCatalogSearchResult>> resolve(
    List<CollectionObjectRef> refs,
  ) async {
    calls += 1;
    return const <String, CollectionCatalogSearchResult>{};
  }
}

final class _CountingPort implements BookingCallablePort {
  int calls = 0;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    calls += 1;
    return <String, Object?>{};
  }
}
