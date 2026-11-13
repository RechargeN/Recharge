import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/find_people_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/find_people_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/discover/data/datasources/catalog_query_port.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_published_find_people_discovery.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_find_people_draft.dart';
import 'support/content_fault_client.dart';
import 'support/stand_backend.dart';

/// D3.7 against the real local stand: the stand creator publishes their own
/// Create Find People draft with the real controller (explicit consent, lost
/// answers, restart), and the real Catalog/Map adapters show it to the adult
/// stand viewer only at the server's ~1 km cell centre. Revoke and hide remove
/// it from the next read; the unattested stand staff user sees nothing.
///
/// Limits: PC host run (no physical device), Sessions from the Auth Emulator.
void main() {
  final StandBackend? stand = StandBackend.fromEnvironment();

  test(
    'Find People: Create controller, consent and Catalog/Map against the Emulator',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final Directory temp = await Directory.systemTemp.createTemp(
        'd37-stand-',
      );
      try {
        await stand!.findPeopleSeed();
        final Map<String, Object?> manifest = await stand.findPeopleManifest();
        final String user = manifest['createdByUserId']! as String;
        final Map<String, Object?> cell =
            manifest['publicLocation']! as Map<String, Object?>;
        final BookingBackendBindingController binding =
            BookingBackendBindingController(
              emulatorBase: StandBackend.functionsBase,
              releaseMode: false,
              initial: BackendBindingMode.testBackend,
            );
        Future<BookingTransportRuntime> signIn(
          String uid,
          String installation, {
          ContentFaultClient? client,
        }) async {
          final BookingTransportRuntime runtime =
              await BookingTransportRuntimeFactory(
                endpoint: binding.endpoint,
                client: client ?? ContentFaultClient(),
                tokens: AuthEmulatorTokenProvider(uid),
                sessions: FileSessionStore(File('${temp.path}/$uid.json')),
                installations: FixedInstallationId(installation),
                supportDirectory: () => Directory(
                  '${temp.path}/support-$uid',
                ).create(recursive: true),
              ).create();
          await runtime.identitySessions!.establish(
            requestId: const Uuid().v4(),
          );
          return runtime;
        }

        final ContentFaultClient faults = ContentFaultClient();
        final BookingTransportRuntime creator = await signIn(
          'stand-user-creator',
          'd37-mobile-creator',
          client: faults,
        );
        final CreateRepositoryImpl repository = CreateRepositoryImpl(
          localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
          idGenerator: UuidV4IdGenerator(),
        );
        await repository.saveDraft(
          user,
          userFindPeopleDraft(
            userId: user,
            localId: 'loc_d37_${const Uuid().v4()}',
            title: 'Morning run (mobile path)',
          ),
        );
        final FindPeoplePublicationTestEntryGuard guard =
            FindPeoplePublicationTestEntryGuard(
              flag: true,
              releaseMode: false,
              binding: binding,
            );
        FindPeoplePublicationController controllerFor() =>
            findPeoplePublicationControllerFor(
              accountId: user,
              defaultContentLocale: 'en',
              port: creator.port!,
              guard: guard,
              drafts: CreateRepositoryFindPeopleDraftSource(repository, user),
              journalFile: File('${temp.path}/journal.json'),
            );
        void ok(FindPeoplePublicationController c) =>
            expect(c.state.message, isNull, reason: c.state.message);

        FindPeoplePublicationController controller = controllerFor();
        await controller.load();
        // A lost update answer: the journaled write is replayed, not duplicated.
        faults.dropNextResponse('updateDraft');
        await controller.save();
        expect(controller.state.phase, FindPeoplePublicationPhase.offline);
        await controller.save();
        ok(controller);
        expect(controller.state.record?.authorApplied, isTrue);
        // Saving is not consent: submit stays closed until the explicit grant.
        expect(controller.state.consent, isNull);
        expect(controller.state.canSubmit, isFalse);
        await controller.grantConsent();
        ok(controller);
        expect(controller.state.consent?.active, isTrue);
        await controller.submit();
        ok(controller);
        final String submission = controller.state.record!.submissionId!;
        await stand.findPeopleFixture(<String>['approve', submission]);
        await controller.refresh();
        faults.dropNextResponse('publishApprovedRevision');
        await controller.publish();
        expect(controller.state.phase, FindPeoplePublicationPhase.offline);
        controller.dispose();
        // The app restarts: a new controller resumes from the same journal.
        controller = controllerFor();
        await controller.load();
        await controller.publish();
        ok(controller);
        expect(controller.state.status?.visibility, 'visible');
        expect(faults.sentCount('publishApprovedRevision'), 2);
        final String contentId = controller.state.record!.contentId;
        await stand.findPeopleFixture(<String>['deliver']);

        Future<List<DiscoverItemEntity>> feed(BookingTransportRuntime viewer) =>
            CatalogDiscoverRepository(
              port: _Callable(viewer.port!),
              session: CatalogSnapshotSession(),
              marketId: 'LV',
              currencyCode: 'EUR',
              findPeopleEnabled: true,
            ).getFeed(
              DiscoverQuery.defaults(
                centerLat: 56.95,
                centerLng: 24.1,
                nowUtc: DateTime.now().toUtc(),
              ),
            );
        Future<PublishedFindPeopleDiscoveryEntity?> details(
          BookingTransportRuntime viewer,
        ) => CatalogPublishedFindPeopleDiscovery(
          port: _Callable(viewer.port!),
          session: CatalogSnapshotSession(),
        ).getActiveFindPeopleRequest(contentId);

        final BookingTransportRuntime viewer = await signIn(
          'stand-user-viewer',
          'd37-mobile-viewer',
        );
        final DiscoverItemEntity listed = (await feed(
          viewer,
        )).firstWhere((DiscoverItemEntity item) => item.id == contentId);
        expect(listed.objectKind, DiscoverObjectKind.findPeople);
        // The MapObject point is the server's cell centre, not the meeting point.
        expect(listed.latitude, cell['latitude']);
        expect(listed.longitude, cell['longitude']);
        expect(listed.latitude, isNot(56.95182));
        final PublishedFindPeopleDiscoveryEntity? shown = await details(viewer);
        expect(shown, isNotNull);
        final PublishedFindPeoplePointLocation location =
            shown!.publicLocation as PublishedFindPeoplePointLocation;
        expect(location.latitude, cell['latitude']);
        expect(location.areaLabel, 'Ķīpsala, Riga');

        // An account without a current 18+ attestation sees nothing.
        final BookingTransportRuntime unattested = await signIn(
          'stand-user-staff',
          'd37-mobile-staff',
        );
        expect(
          (await feed(unattested)).any(
            (DiscoverItemEntity item) =>
                item.objectKind == DiscoverObjectKind.findPeople,
          ),
          isFalse,
        );
        expect(await details(unattested), isNull);

        // Revoke: gone from the next read; consent again: back.
        await controller.revokeConsent();
        ok(controller);
        expect(await details(viewer), isNull);
        expect(
          (await feed(
            viewer,
          )).any((DiscoverItemEntity item) => item.id == contentId),
          isFalse,
        );
        await controller.grantConsent();
        ok(controller);
        expect(await details(viewer), isNotNull);
        // Owner hide: gone before any Catalog delivery.
        await controller.hide();
        ok(controller);
        expect(controller.state.status?.visibility, 'withdrawn');
        expect(await details(viewer), isNull);
        controller.dispose();
      } finally {
        await temp.delete(recursive: true);
      }
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// The authenticated Functions transport, as the Discover composition wires it.
final class _Callable implements CatalogQueryPort {
  const _Callable(this._port);

  final BookingCallablePort _port;

  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) async {
    try {
      return await _port.invoke('discoverQueryV1', request);
    } on BookingCallableFailure catch (error) {
      throw CatalogTransportFailure(error.code);
    }
  }
}
