import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/discover_catalog_composition.dart';
import 'package:recharge/app/di/find_people_publication_composition.dart';
import 'package:recharge/features/discover/data/datasources/catalog_query_port.dart';
import 'package:recharge/features/discover/data/repositories/catalog_published_find_people_discovery.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/published_find_people_discovery_port.dart';

/// D3.7: the Find People publication entry and its Catalog read are their own
/// default-off switches; without every condition nothing reaches the server.
void main() {
  final Uri base = Uri.parse(
    'http://127.0.0.1:5001/demo-recharge/europe-west1',
  );

  FindPeoplePublicationTestEntryGuard guard({
    bool flag = true,
    bool release = false,
    BackendBindingMode mode = BackendBindingMode.testBackend,
    Uri? emulatorBase,
  }) => FindPeoplePublicationTestEntryGuard(
    flag: flag,
    releaseMode: release,
    binding: BookingBackendBindingController(
      emulatorBase: emulatorBase ?? base,
      releaseMode: release,
      initial: mode,
    ),
  );

  test('the define is off by default in every test run', () {
    expect(findPeoplePublicationTestEntryDefined, isFalse);
    expect(findPeopleCatalogTestEntryDefined, isFalse);
  });

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
    expect(() => guard(flag: false).assertAllowed(), throwsStateError);
    expect(
      findPeoplePublicationTestEntryRedirect(guard(flag: false), fallback: '/'),
      '/',
    );
    expect(findPeoplePublicationTestEntryRedirect(null, fallback: '/'), '/');
    expect(
      findPeoplePublicationTestEntryRedirect(guard(), fallback: '/'),
      isNull,
    );
  });

  test(
    'Details over the Catalog only under testBackend with its own define',
    () {
      final _Local local = _Local();
      PublishedFindPeopleDiscoveryPort pick(
        BackendBindingMode mode,
        bool enabled,
      ) => publishedFindPeopleDiscoveryFor(
        manifest: BackendBindingManifest(
          revision: 1,
          bindings: <String, BackendBindingMode>{
            discoverCatalogCapabilityId: mode,
          },
        ),
        local: () => local,
        port: const _NoPort(),
        session: CatalogSnapshotSession(),
        enabled: enabled,
      );
      expect(
        pick(BackendBindingMode.testBackend, true),
        isA<CatalogPublishedFindPeopleDiscovery>(),
      );
      expect(pick(BackendBindingMode.testBackend, false), same(local));
      expect(pick(BackendBindingMode.localOnly, true), same(local));
      expect(
        pick(BackendBindingMode.disabled, true).getActiveFindPeopleRequest('x'),
        throwsA(anything),
      );
    },
  );
}

final class _Local implements PublishedFindPeopleDiscoveryPort {
  @override
  Future<PublishedFindPeopleDiscoveryEntity?> getActiveFindPeopleRequest(
    String requestId,
  ) async => null;
}

final class _NoPort implements CatalogQueryPort {
  const _NoPort();

  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) =>
      throw StateError('no Catalog in this test');
}
