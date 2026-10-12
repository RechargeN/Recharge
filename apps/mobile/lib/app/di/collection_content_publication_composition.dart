import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/collection_content_publication_controller.dart';
import '../../features/create/data/file_collection_publication_journal.dart';
import '../../features/create/data/file_event_publication_journal.dart';
import '../../features/create/data/functions_event_publication_gateway.dart';
import '../../features/create/data/repositories/catalog_collection_catalog_search_repository.dart';
import '../../features/create/domain/entities/collection_item_draft.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/repositories/collection_catalog_search_repository.dart';
import '../../features/create/domain/repositories/collection_content_publication_gateway.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'event_publication_composition.dart';
import 'media_composition.dart';
import 'service_locator.dart';

/// Compile-time switch of its own, separate from the Booking, Event, Place and
/// Activity ones. `bool.fromEnvironment` only recognises `true`:
/// `--dart-define=RECHARGE_TEST_COLLECTION_PUBLICATION=true`.
const bool collectionPublicationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_COLLECTION_PUBLICATION',
);

/// Default-off test entry for the Collection publication path (D3.4 §5.1).
/// All four conditions must hold at once, and the same check protects the
/// route, the Create item picker over the Catalog, every Content command and
/// every Media upload: the define is `true`, the build is not release, the
/// binding is `testBackend`, and the endpoint is the loopback
/// `demo-recharge/europe-west1` Emulator.
final class CollectionPublicationTestEntryGuard
    implements
        CollectionPublicationCommandGate,
        EventPublicationCommandGate,
        MediaCommandGate {
  CollectionPublicationTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory CollectionPublicationTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => CollectionPublicationTestEntryGuard(
    flag: collectionPublicationTestEntryDefined,
    releaseMode: kReleaseMode,
    binding: binding,
  );

  final bool flag;
  final bool releaseMode;
  final BookingBackendBindingController _binding;

  @override
  bool get allowed =>
      flag &&
      !releaseMode &&
      _binding.mode == BackendBindingMode.testBackend &&
      isLoopbackDemoEmulatorBinding(_binding);

  @override
  void assertAllowed() {
    if (!allowed) {
      throw StateError('Collection publication test entry is not enabled');
    }
  }
}

/// Route guard: where to send a visitor of the test route, or null to let them
/// in. A missing guard (nothing registered) is a refusal.
String? collectionPublicationTestEntryRedirect(
  CollectionPublicationTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// The Catalog read (`discoverQueryV1`) of the Collection test entry: every
/// call re-checks its guard and the authenticated `testBackend` transport.
Future<Map<String, Object?>> Function(Map<String, Object?>)
collectionCatalogQueryFor({
  required CollectionPublicationTestEntryGuard guard,
  required Future<BookingTransportRuntime> Function() runtime,
}) => (Map<String, Object?> request) async {
  guard.assertAllowed();
  final BookingTransportRuntime current = await runtime();
  final BookingCallablePort? port = current.port;
  if (!current.remoteCommandsEnabled || port == null) {
    throw StateError('transport_unavailable');
  }
  return port.invoke('discoverQueryV1', request);
};

/// The Create item picker for the binding: the server Catalog while the
/// Collection test entry is allowed, the existing local catalog otherwise.
/// Decided on every call, so a binding rolled back to `localOnly` stops
/// reaching the Catalog at once.
final class TestEntryCollectionCatalogSearchRepository
    implements CollectionCatalogSearchRepository {
  const TestEntryCollectionCatalogSearchRepository({
    required CollectionPublicationTestEntryGuard guard,
    required CollectionCatalogSearchRepository server,
    required CollectionCatalogSearchRepository local,
  }) : _guard = guard,
       _server = server,
       _local = local;

  final CollectionPublicationTestEntryGuard _guard;
  final CollectionCatalogSearchRepository _server;
  final CollectionCatalogSearchRepository _local;

  CollectionCatalogSearchRepository get _current =>
      _guard.allowed ? _server : _local;

  @override
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  ) => _current.search(query);

  @override
  Future<Map<String, CollectionCatalogSearchResult>> resolve(
    List<CollectionObjectRef> refs,
  ) => _current.resolve(refs);
}

/// The user's current Create draft, read through the Create repository.
final class CreateRepositoryCollectionDraftSource
    implements CollectionDraftSource {
  const CreateRepositoryCollectionDraftSource(this._repository, this._userId);

  final CreateRepository _repository;
  final String _userId;

  @override
  Future<CreateDraftEntity?> current() => _repository.loadDraft(_userId);
}

/// Wires the controller from explicit parts (used by tests and production).
CollectionContentPublicationController
collectionContentPublicationControllerFor({
  required String accountId,
  required BookingCallablePort port,
  required CollectionPublicationTestEntryGuard guard,
  required CollectionDraftSource drafts,
  required CollectionMembershipReader membership,
  required File journalFile,
  EventCoverSource mediaSource = const FileEventCoverSource(),
}) {
  final FunctionsEventPublicationGateway gateway =
      FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter(port),
        gate: guard,
        typeId: 'collection',
      );
  return CollectionContentPublicationController(
    accountId: accountId,
    drafts: drafts,
    gateway: gateway,
    reader: gateway,
    // Every photo goes through the C1 Media adapter, gated by this entry.
    uploader: MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: guard),
    ),
    mediaSource: mediaSource,
    journal: FileCollectionPublicationJournal(journalFile),
    membership: membership,
    gate: guard,
  );
}

/// Builds the controller from the real `testBackend` runtime and the user's
/// Create repository, or null unless the whole test entry is allowed.
Future<CollectionContentPublicationController?>
createCollectionContentPublicationController({required String userId}) async {
  if (!sl.isRegistered<CollectionPublicationTestEntryGuard>()) return null;
  final CollectionPublicationTestEntryGuard guard =
      sl<CollectionPublicationTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.port;
  if (!runtime.remoteCommandsEnabled || port == null) return null;
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return collectionContentPublicationControllerFor(
    accountId: userId,
    port: port,
    guard: guard,
    drafts: CreateRepositoryCollectionDraftSource(
      sl<CreateRepository>(),
      userId,
    ),
    membership: sl<CatalogCollectionCatalogSearchRepository>(),
    journalFile: File(
      '${support.path}${separator}content${separator}collection-publications-v1.json',
    ),
  );
}
