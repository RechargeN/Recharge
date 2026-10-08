import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/booking_test_entry_guard.dart';
import 'package:recharge/app/di/discover_catalog_composition.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/application/event_booking_controller.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_event_booking_gateway.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/booking/data/file_event_booking_operation_store.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';
import 'package:recharge/features/create/application/event_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_published_event_discovery.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/event_occurrence.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_event_draft.dart';
import 'support/e2_rendezvous.dart';
import 'support/stand_backend.dart';

/// E2b: one of two independent local clients, started as its own `flutter
/// test` process by `stand-e2-gate.mjs` (role A or B). Each has its own stand
/// user, Firebase account, Session, installation id and journals, and reaches
/// the shared stand only through the real adapters. Client A is the seeded
/// Creator; client B is the second Creator of the gate's fixture.
///
/// Both: Create → moderation (staff at the gate's rendezvous) → publication →
/// Catalog → Feed/Search → Details of the same revision → Booking of the
/// peer's Event (a repeated command makes no duplicate) → cancel. Then A hides
/// its Event while B books it, overlapping in time; after Booking applied the
/// hide, B's new Booking is refused and the Event leaves B's Feed and Details.
///
/// Limits: PC host against the local Emulator; evidence of two independent
/// test clients, not of two physical phones.
void main() {
  final StandBackend? stand = StandBackend.fromEnvironment();
  final E2Rendezvous? rendezvous = E2Rendezvous.fromEnvironment();
  final String? pageId = Platform.environment['RECHARGE_E2_PAGE_ID'];
  final bool skip = stand == null || rendezvous == null || pageId == null;
  late Directory temp;
  late File cover;
  final runtimes = <String, Future<BookingTransportRuntime>>{};

  BookingBackendBindingController binding() => BookingBackendBindingController(
    emulatorBase: StandBackend.functionsBase,
    releaseMode: false,
    initial: BackendBindingMode.testBackend,
  );

  Future<BookingTransportRuntime> runtimeFor(
    String label,
    String role,
  ) => runtimes.putIfAbsent(label, () async {
    final sessions = FileSessionStore(File('${temp.path}/session-$label.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding().endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-$label'),
      sessions: sessions,
      installations: FixedInstallationId('e2-installation-$role'),
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

  /// Polls a real read until [done] holds; the deadline is the only wait.
  Future<T> eventually<T>(
    Future<T> Function() read,
    bool Function(T value) done, {
    required String what,
  }) async {
    final DateTime deadline = DateTime.now().add(const Duration(minutes: 3));
    while (true) {
      final T value = await read();
      if (done(value)) return value;
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  setUpAll(() async {
    if (skip) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('e2-client-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
  });

  tearDownAll(() async {
    if (!skip && await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'E2 client: Create → moderation → Catalog → Details → Booking → cancel, '
    'then the hide race',
    () async {
      final E2Rendezvous meeting = rendezvous!;
      final String role = meeting.role;
      final String label = role == 'A' ? 'creator' : 'viewer';
      final String marker =
          'e2$role${const Uuid().v4().replaceAll('-', '').substring(0, 10)}';
      final DateTime day = DateTime.now().toUtc().add(const Duration(days: 30));
      final String date =
          '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';

      // 1. Create: the user's own draft with internal registration v1.
      final draft = withInternalRegistration(
        userEventDraft(
          pageId: pageId!,
          coverPath: cover.path,
          localId: 'loc_e2_${const Uuid().v4()}',
          title: 'Clay evening $marker',
          localStartDate: date,
        ),
        capacity: 5,
      );
      final repository = CreateRepositoryImpl(
        localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
        idGenerator: UuidV4IdGenerator(),
      );
      await repository.saveDraft('user-$label', draft);
      final BookingTransportRuntime runtime = await runtimeFor(label, role);
      final EventPublicationController creator = eventPublicationControllerFor(
        port: runtime.port!,
        guard: EventPublicationTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: binding(),
        ),
        drafts: CreateRepositoryEventDraftSource(repository, 'user-$label'),
        journalFile: File('${temp.path}/journal-publication-$role.json'),
      );
      await creator.load();
      await creator.save();
      expect(creator.state.message, isNull, reason: creator.state.message);
      await creator.uploadCover();
      expect(creator.state.message, isNull, reason: creator.state.message);
      await creator.submit();
      expect(creator.state.message, isNull, reason: creator.state.message);
      expect(creator.state.status?.latestSubmissionState, 'under_review');

      // 2. Moderation: staff approves both submissions at the gate.
      await meeting.arrive('submitted', <String, Object?>{
        'submissionId': creator.state.status!.latestSubmissionId,
        'contentId': creator.state.record!.contentId,
      });
      await meeting.waitFor('gate', 'approved.$role');

      // 3. Publication.
      await creator.refresh();
      await creator.publish();
      expect(creator.state.message, isNull, reason: creator.state.message);
      expect(creator.state.status?.visibility, 'visible');
      final Map<String, Object?> peer = await meeting
          .barrier('published', <String, Object?>{
            'contentId': creator.state.record!.contentId,
            'revision': creator.state.status!.currentPublishedRevisionId,
            'marker': marker,
          });
      final String peerContent = peer['contentId']! as String;
      final String peerRevision = peer['revision']! as String;

      // 4. Discover through the real adapters: Feed, Search, Details.
      final port = BookingPortCatalogAdapter(
        runtime: () async => runtime,
        guard: DiscoverCatalogTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: binding(),
        ),
      );
      final session = CatalogSnapshotSession();
      final listing = CatalogDiscoverRepository(
        port: port,
        session: session,
        marketId: 'LV',
        currencyCode: 'EUR',
      );
      final details = CatalogPublishedEventDiscovery(
        port: port,
        session: session,
        currencyCode: 'EUR',
      );
      final DiscoverQuery query = DiscoverQuery.defaults(
        centerLat: 56.9496,
        centerLng: 24.1052,
      );
      bool listsPeer(List<DiscoverItemEntity> items) =>
          items.any((DiscoverItemEntity item) => item.id == peerContent);
      final List<DiscoverItemEntity> feed = await eventually(
        () => listing.getFeed(query),
        listsPeer,
        what: 'the peer Event in the Feed',
      );
      expect(
        feed.firstWhere((item) => item.id == peerContent).revisionRef,
        peerRevision,
      );
      final List<DiscoverItemEntity> search = await listing.getFeed(
        query.copyWith(queryText: peer['marker']! as String),
      );
      expect(search.map((item) => item.id), <String>[peerContent]);
      final PublishedEventDiscoveryEntity? event = await details.getActiveEvent(
        peerContent,
      );
      expect(event?.revisionRef, peerRevision, reason: 'same revision');
      expect(event!.changedSinceListing, isFalse);
      final EventBookingRef? ref = event.displayOccurrence?.bookingRef;
      expect(ref, isNotNull, reason: 'internal registration is bookable');

      // 5. Booking terms come from Booking, never from the Catalog.
      final gateway = BookingTransportEventBookingGateway(
        adapter: runtime.adapter!,
        port: runtime.port!,
        gate: BookingTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: binding(),
        ),
      );
      Future<EventBookingTermsResult> terms() => gateway.termsFor(
        eventId: ref!.eventId,
        occurrenceId: ref.occurrenceId,
        channel: ref.channel,
      );
      final EventBookingTerms offered = (await eventually(
        terms,
        (EventBookingTermsResult result) => result.terms?.open ?? false,
        what: 'Booking terms of the peer occurrence',
      )).terms!;
      expect(offered.inventoryPoolId, startsWith('pool_'));
      expect(offered.channel, 'onsite');
      expect(offered.maxParticipantUnits, 2);

      // 6. Book, repeat the same command (no duplicate), cancel.
      final ({int total, int active}) before = await stand!.bookingCounts(
        label,
      );
      final EventBookingOperation intent = EventBookingOperation(
        kind: EventBookingOperationKind.create,
        idempotencyKey: 'e2-$marker',
        occurrenceId: offered.occurrenceId,
        inventoryPoolId: offered.inventoryPoolId,
        channel: offered.channel,
        participantUnits: 1,
        eventRevision: offered.eventRevision,
      );
      final EventBookingResult first = await gateway.execute(intent);
      final EventBookingResult repeated = await gateway.execute(intent);
      expect(first.outcome, EventBookingOutcome.succeeded);
      expect(repeated.outcome, EventBookingOutcome.succeeded);
      expect(repeated.booking?.id, first.booking?.id, reason: 'replayed');
      final ({int total, int active}) booked = await stand.bookingCounts(label);
      expect(booked.total, before.total + 1, reason: 'one Booking only');
      expect(booked.active, before.active + 1);

      EventBookingController controllerFor(EventBookingTerms terms) =>
          EventBookingController(
            gateway: gateway,
            store: FileEventBookingOperationStore(
              File('${temp.path}/journal-booking-$role.json'),
            ),
            occurrenceId: terms.occurrenceId,
            inventoryPoolId: terms.inventoryPoolId,
            channel: terms.channel,
            eventRevision: terms.eventRevision,
          );
      final EventBookingController booking = controllerFor(offered);
      await booking.load();
      expect(booking.state.booking?.id, first.booking?.id);
      await booking.cancel();
      expect(booking.state.booking?.isActive ?? false, isFalse);
      expect((await stand.bookingCounts(label)).active, before.active);
      await meeting.barrier('booked-and-cancelled');

      // 7. The race: A hides its Event while B books it.
      await meeting.barrier('race');
      if (role == 'A') {
        await creator.hide();
        expect(creator.state.status?.visibility, 'withdrawn');
        await meeting.arrive('hidden');
      } else {
        await booking.book();
        final bool racedIn = booking.state.booking?.isActive ?? false;
        await meeting.waitFor('A', 'hidden');
        // Eventual consistency: the guarantee starts once Booking applied it.
        await eventually(
          terms,
          (EventBookingTermsResult result) =>
              result.outcome == EventBookingTermsOutcome.unavailable,
          what: 'Booking to apply the hide',
        );
        final EventBookingResult refused = await gateway.execute(
          EventBookingOperation(
            kind: EventBookingOperationKind.create,
            idempotencyKey: 'e2-after-hide-$marker',
            occurrenceId: offered.occurrenceId,
            inventoryPoolId: offered.inventoryPoolId,
            channel: offered.channel,
            participantUnits: 1,
            eventRevision: offered.eventRevision,
          ),
        );
        if (racedIn) {
          // Booked before the hide reached Booking: it stays and is cancellable.
          expect(refused.outcome, EventBookingOutcome.rejected);
          await booking.load();
          expect(booking.state.booking?.isActive, isTrue);
          await booking.cancel();
          expect(booking.state.booking?.isActive ?? false, isFalse);
        } else {
          expect(refused.outcome, EventBookingOutcome.rejected);
        }
        await eventually(
          () => listing.getFeed(query),
          (List<DiscoverItemEntity> items) => !listsPeer(items),
          what: 'the hidden Event to leave the Feed',
        );
        expect(await details.getActiveEvent(peerContent), isNull);
        await meeting.arrive('race-result', <String, Object?>{
          'bookedBeforeHide': racedIn,
        });
      }
      await meeting.barrier('done');
      creator.dispose();
      booking.dispose();
    },
    skip: skip ? 'run by apps/backend/scripts/stand-e2-gate.mjs' : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
