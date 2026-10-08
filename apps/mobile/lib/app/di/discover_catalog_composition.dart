import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/discover/data/datasources/catalog_query_port.dart';
import '../../features/discover/data/repositories/catalog_discover_repository.dart';
import '../../features/discover/data/repositories/catalog_published_event_discovery.dart';
import '../../features/discover/data/repositories/catalog_snapshot_session.dart';
import '../../features/discover/domain/entities/discover_item_entity.dart';
import '../../features/discover/domain/entities/discover_query.dart';
import '../../features/discover/domain/entities/published_event_discovery_entity.dart';
import '../../features/discover/domain/repositories/discover_repository.dart';
import '../../features/discover/domain/repositories/published_event_discovery_port.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';

/// Capability id under which the Discover read binding is recorded in a
/// [BackendBindingManifest] (E2).
const String discoverCatalogCapabilityId = 'discover.catalog';

/// Compile-time switch, separate from the Booking and Publication ones:
/// `--dart-define=RECHARGE_TEST_DISCOVER_CATALOG=true`.
const bool discoverCatalogTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_DISCOVER_CATALOG',
);

/// Default-off test entry for Discover over the server Catalog (E2). All four
/// conditions must hold at once, and the same check protects every read: the
/// define is `true`, the build is not release, the binding is `testBackend`,
/// and the endpoint is the loopback `demo-recharge/europe-west1` Emulator.
final class DiscoverCatalogTestEntryGuard {
  DiscoverCatalogTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory DiscoverCatalogTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => DiscoverCatalogTestEntryGuard(
    flag: discoverCatalogTestEntryDefined,
    releaseMode: kReleaseMode,
    binding: binding,
  );

  final bool flag;
  final bool releaseMode;
  final BookingBackendBindingController _binding;

  bool get allowed =>
      flag &&
      !releaseMode &&
      _binding.mode == BackendBindingMode.testBackend &&
      isLoopbackDemoEmulatorBinding(_binding);
}

/// The Discover binding manifest: `testBackend` only while the whole test entry
/// is allowed, otherwise the existing local Discover data (`localOnly`). A
/// release build never reaches the Catalog.
BackendBindingManifest discoverBindingManifest(
  DiscoverCatalogTestEntryGuard guard,
) => BackendBindingManifest(
  revision: 1,
  bindings: <String, BackendBindingMode>{
    discoverCatalogCapabilityId: guard.allowed
        ? BackendBindingMode.testBackend
        : BackendBindingMode.localOnly,
  },
);

/// Lets Discover use the authenticated Functions transport without the
/// Discover feature importing the Booking feature. Every read re-checks the
/// guard, so a binding rolled back to `localOnly` stops reaching the Catalog.
final class BookingPortCatalogAdapter implements CatalogQueryPort {
  const BookingPortCatalogAdapter({
    required Future<BookingTransportRuntime> Function() runtime,
    required DiscoverCatalogTestEntryGuard guard,
  }) : _runtime = runtime,
       _guard = guard;

  final Future<BookingTransportRuntime> Function() _runtime;
  final DiscoverCatalogTestEntryGuard _guard;

  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) async {
    if (!_guard.allowed) {
      throw const CatalogTransportFailure('test_entry_disabled');
    }
    final BookingTransportRuntime runtime = await _runtime();
    final BookingCallablePort? port = runtime.port;
    if (!runtime.remoteCommandsEnabled || port == null) {
      throw const CatalogTransportFailure('transport_unavailable');
    }
    try {
      return await port.invoke('discoverQueryV1', request);
    } on BookingCallableFailure catch (error) {
      throw CatalogTransportFailure(error.code);
    }
  }
}

/// A capability bound to `disabled`: every read is a typed refusal.
final class DisabledDiscoverRepository
    implements DiscoverRepository, PublishedEventDiscoveryPort {
  const DisabledDiscoverRepository();

  static const DiscoverException _refusal = DiscoverException(
    code: 'DISCOVER_DISABLED',
    message: 'Discover недоступен',
  );

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) =>
      Future<List<DiscoverItemEntity>>.error(_refusal);

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) =>
      Future<DiscoverItemEntity>.error(_refusal);

  @override
  Future<PublishedEventDiscoveryEntity?> getActiveEvent(String eventId) =>
      Future<PublishedEventDiscoveryEntity?>.error(_refusal);
}

/// The Discover listing for the binding: the Catalog under `testBackend`, the
/// existing local data under `localOnly`.
DiscoverRepository discoverRepositoryFor({
  required BackendBindingManifest manifest,
  required DiscoverRepository Function() local,
  required CatalogQueryPort port,
  required CatalogSnapshotSession session,
  required String marketId,
  required String currencyCode,
}) => switch (manifest.modeFor(discoverCatalogCapabilityId)) {
  BackendBindingMode.testBackend => CatalogDiscoverRepository(
    port: port,
    session: session,
    marketId: marketId,
    currencyCode: currencyCode,
  ),
  BackendBindingMode.localOnly => local(),
  BackendBindingMode.disabled => const DisabledDiscoverRepository(),
};

/// Event Details for the binding, on the same snapshot as the listing.
PublishedEventDiscoveryPort publishedEventDiscoveryFor({
  required BackendBindingManifest manifest,
  required PublishedEventDiscoveryPort Function() local,
  required CatalogQueryPort port,
  required CatalogSnapshotSession session,
  required String currencyCode,
}) => switch (manifest.modeFor(discoverCatalogCapabilityId)) {
  BackendBindingMode.testBackend => CatalogPublishedEventDiscovery(
    port: port,
    session: session,
    currencyCode: currencyCode,
  ),
  BackendBindingMode.localOnly => local(),
  BackendBindingMode.disabled => const DisabledDiscoverRepository(),
};
