import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/discover_catalog_composition.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/discover/data/datasources/catalog_query_port.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_published_event_discovery.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/repositories/published_event_discovery_port.dart';

final class _LocalDiscover
    implements DiscoverRepository, PublishedEventDiscoveryPort {
  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async =>
      const <DiscoverItemEntity>[];

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) =>
      throw UnimplementedError();

  @override
  Future<PublishedEventDiscoveryEntity?> getActiveEvent(String eventId) async =>
      null;
}

final class _NoPort implements CatalogQueryPort {
  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) =>
      throw StateError('never called');
}

void main() {
  final Uri base = Uri.parse(
    'http://127.0.0.1:5001/demo-recharge/europe-west1',
  );

  DiscoverCatalogTestEntryGuard guard({
    bool flag = true,
    bool release = false,
    BackendBindingMode mode = BackendBindingMode.testBackend,
    Uri? emulatorBase,
  }) => DiscoverCatalogTestEntryGuard(
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
        emulatorBase: Uri.parse('http://127.0.0.1:5001/real/europe-west1'),
      ).allowed,
      isFalse,
    );
  });

  test(
    'the compile-time define is off unless set to true',
    () {
      expect(discoverCatalogTestEntryDefined, isFalse);
      expect(
        discoverBindingManifest(
          DiscoverCatalogTestEntryGuard.fromEnvironment(
            BookingBackendBindingController(
              emulatorBase: base,
              releaseMode: false,
              initial: BackendBindingMode.testBackend,
            ),
          ),
        ).modeFor(discoverCatalogCapabilityId),
        BackendBindingMode.localOnly,
      );
    },
    skip: discoverCatalogTestEntryDefined ? 'run with the define on' : false,
  );

  test('the manifest binds discover.catalog to testBackend only under the '
      'guard, and selects the adapters from it', () {
    final BackendBindingManifest on = discoverBindingManifest(guard());
    final BackendBindingManifest off = discoverBindingManifest(
      guard(flag: false),
    );
    expect(
      on.modeFor(discoverCatalogCapabilityId),
      BackendBindingMode.testBackend,
    );
    expect(
      off.modeFor(discoverCatalogCapabilityId),
      BackendBindingMode.localOnly,
    );
    final _LocalDiscover local = _LocalDiscover();
    final CatalogSnapshotSession session = CatalogSnapshotSession();
    DiscoverRepository listing(BackendBindingManifest manifest) =>
        discoverRepositoryFor(
          manifest: manifest,
          local: () => local,
          port: _NoPort(),
          session: session,
          marketId: 'LV',
          currencyCode: 'EUR',
        );
    PublishedEventDiscoveryPort details(BackendBindingManifest manifest) =>
        publishedEventDiscoveryFor(
          manifest: manifest,
          local: () => local,
          port: _NoPort(),
          session: session,
          currencyCode: 'EUR',
        );
    expect(listing(on), isA<CatalogDiscoverRepository>());
    expect(details(on), isA<CatalogPublishedEventDiscovery>());
    expect(listing(off), same(local));
    expect(details(off), same(local));
    final BackendBindingManifest disabled = BackendBindingManifest(
      revision: 1,
      bindings: <String, BackendBindingMode>{},
    );
    expect(listing(disabled), isA<DisabledDiscoverRepository>());
    expect(details(disabled), isA<DisabledDiscoverRepository>());
  });

  test('the transport adapter refuses every read once the guard is off', () {
    var runtimeAsked = false;
    final BookingPortCatalogAdapter adapter = BookingPortCatalogAdapter(
      runtime: () {
        runtimeAsked = true;
        return Future<BookingTransportRuntime>.error(StateError('unused'));
      },
      guard: guard(flag: false),
    );
    expect(
      adapter.query(const <String, Object?>{}),
      throwsA(
        isA<CatalogTransportFailure>().having(
          (CatalogTransportFailure failure) => failure.code,
          'code',
          'test_entry_disabled',
        ),
      ),
    );
    expect(runtimeAsked, isFalse);
  });
}
