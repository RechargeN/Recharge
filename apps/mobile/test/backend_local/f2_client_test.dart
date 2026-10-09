import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/booking_test_entry_guard.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/notifications_inbox_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/application/event_booking_controller.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_event_booking_gateway.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/booking/data/file_event_booking_operation_store.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';
import 'package:recharge/features/create/application/event_create_coordinator.dart';
import 'package:recharge/features/create/application/event_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/build_event_content_body.dart';
import 'package:recharge/features/create/domain/usecases/materialize_event_schedule_usecase.dart';
import 'package:recharge/features/notifications/data/remote/server_notifications_repository.dart';
import 'package:recharge/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_event_draft.dart';
import 'support/e2_rendezvous.dart';
import 'support/stand_backend.dart';

/// F2: one of two independent local clients started by `stand-f2-gate.mjs`.
/// Role A is the organizer (seeded Creator), role B the participant (seeded
/// viewer); each has its own user, Session, installation id and journals and
/// reaches the shared stand only through the real adapters.
///
/// A creates a one-time Event E1 and a two-date Event E2 through Create; B
/// books two seats of E1 and one date of E2. A moves E1 twice through the real
/// Create coordinator (the occurrence and Booking keep their ids) and removes
/// the booked date of E2. B sees each change by Refresh and in the inbox,
/// reconfirms, has a stale answer refused and sees the cancellation reason.
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

  BookingBackendBindingController binding() => BookingBackendBindingController(
    emulatorBase: StandBackend.functionsBase,
    releaseMode: false,
    initial: BackendBindingMode.testBackend,
  );

  Future<BookingTransportRuntime> runtimeFor(String label, String role) async {
    final sessions = FileSessionStore(File('${temp.path}/session-$label.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding().endpoint,
      client: _FreshConnectionClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-$label'),
      sessions: sessions,
      installations: FixedInstallationId('f2-installation-$role'),
      supportDirectory: () async =>
          Directory('${temp.path}/support-$label').create(recursive: true),
    ).create();
    try {
      await runtime.identitySessions!.establish(requestId: const Uuid().v4());
    } on BookingCallableFailure catch (error) {
      fail('establish failed for $label with ${error.code}');
    }
    return runtime;
  }

  Future<T> eventually<T>(
    Future<T> Function() read,
    bool Function(T value) done, {
    required String what,
    String Function(T value)? detail,
  }) async {
    final DateTime deadline = DateTime.now().add(const Duration(minutes: 3));
    while (true) {
      final T value = await read();
      if (done(value)) return value;
      if (DateTime.now().isAfter(deadline)) {
        fail(
          'timed out waiting for $what'
          '${detail == null ? '' : ' (last: ${detail(value)})'}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  String isoDate(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  setUpAll(() async {
    if (skip) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('f2-client-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
  });

  tearDownAll(() async {
    if (!skip && await temp.exists()) await temp.delete(recursive: true);
  });

  final EventCreateCoordinator coordinator = EventCreateCoordinator(
    materializeSchedule: MaterializeEventScheduleUseCase(
      EventTimezoneRepositoryImpl(),
    ),
  );
  final DateTime base = DateTime.now().toUtc().add(const Duration(days: 30));
  final String d1 = isoDate(base);
  final String d2 = isoDate(base.add(const Duration(days: 1)));
  final String moved1 = isoDate(base.add(const Duration(days: 3)));
  final String moved2 = isoDate(base.add(const Duration(days: 5)));

  Future<void> organizer(E2Rendezvous meeting) async {
    final BookingTransportRuntime runtime = await runtimeFor('creator', 'A');
    final String marker = const Uuid().v4().substring(0, 8);
    EventPublicationController publisher(
      CreateRepositoryImpl repo,
      String key,
    ) => eventPublicationControllerFor(
      port: runtime.port!,
      guard: EventPublicationTestEntryGuard(
        flag: true,
        releaseMode: false,
        binding: binding(),
      ),
      drafts: CreateRepositoryEventDraftSource(repo, key),
      journalFile: File('${temp.path}/journal-$key.json'),
    );
    CreateRepositoryImpl repository() => CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );

    // E1: one-time; E2: two dates. Both through Create's own coordinator.
    final CreateRepositoryImpl repoE1 = repository();
    final CreateRepositoryImpl repoE2 = repository();
    final CreateDraftEntity e1 = withInternalRegistration(
      userEventDraft(
        pageId: pageId!,
        coverPath: cover.path,
        localId: 'loc_f2_e1_$marker',
        title: 'Reschedule check $marker',
        localStartDate: d1,
      ),
      capacity: 5,
    );
    final CreateDraftEntity e2Base = withInternalRegistration(
      userEventDraft(
        pageId: pageId,
        coverPath: cover.path,
        localId: 'loc_f2_e2_$marker',
        title: 'Two dates check $marker',
        localStartDate: d1,
      ),
      capacity: 5,
    );
    final CreateDraftEntity e2 = coordinator.apply(
      e2Base,
      e2Base.eventData!.copyWith(
        scheduleMode: EventScheduleMode.multiDate,
        multiDateLocalDates: <String>[d1, d2],
      ),
    );
    expect(e2.eventData!.occurrences, hasLength(2));
    await repoE1.saveDraft('user-creator-e1', e1);
    await repoE2.saveDraft('user-creator-e2', e2);
    final EventPublicationController p1 = publisher(repoE1, 'user-creator-e1');
    final EventPublicationController p2 = publisher(repoE2, 'user-creator-e2');

    Future<String> submit(EventPublicationController controller) async {
      await controller.load();
      await controller.save();
      expect(
        controller.state.message,
        isNull,
        reason: controller.state.message,
      );
      await controller.uploadCover();
      await controller.submit();
      expect(
        controller.state.message,
        isNull,
        reason: controller.state.message,
      );
      return controller.state.status!.latestSubmissionId!;
    }

    Future<void> publish(EventPublicationController controller) async {
      await controller.refresh();
      await controller.publish();
      expect(
        controller.state.message,
        isNull,
        reason: controller.state.message,
      );
    }

    await meeting.arrive('submitted', <String, Object?>{
      'submissionIds': <String>[await submit(p1), await submit(p2)],
    });
    await meeting.waitFor('gate', 'approved');
    await publish(p1);
    await publish(p2);
    final String e1Occurrence = EventContentBodyMapper.serverOccurrenceId(
      e1.id,
      e1.eventData!.occurrences.single.id,
    );
    final List<String> e2Occurrences = <String>[
      for (final EventOccurrenceDraft occurrence in e2.eventData!.occurrences)
        EventContentBodyMapper.serverOccurrenceId(e2.id, occurrence.id),
    ];
    await meeting.arrive('published', <String, Object?>{
      'e1': p1.state.record!.contentId,
      'e1Occurrence': e1Occurrence,
      'e2': p2.state.record!.contentId,
      'e2Occurrences': e2Occurrences,
    });
    await meeting.waitFor('B', 'booked');

    // Move E1 through Create: the same occurrence, so the same server id.
    Future<void> moveE1(String date, String point) async {
      final CreateDraftEntity current = (await repoE1.loadDraft(
        'user-creator-e1',
      ))!;
      final CreateDraftEntity moved = coordinator.apply(
        current,
        current.eventData!.copyWith(localStartDate: date),
      );
      expect(
        moved.eventData!.occurrences.single.id,
        current.eventData!.occurrences.single.id,
        reason: 'a reschedule keeps the occurrence',
      );
      expect(
        EventContentBodyMapper.serverOccurrenceId(
          moved.id,
          moved.eventData!.occurrences.single.id,
        ),
        e1Occurrence,
      );
      await repoE1.saveDraft('user-creator-e1', moved);
      await meeting.arrive('resubmitted-$point', <String, Object?>{
        'submissionIds': <String>[await submit(p1)],
      });
      await meeting.waitFor('gate', 'approved-$point');
      await publish(p1);
      await meeting.arrive('rescheduled-$point');
    }

    await moveE1(moved1, '1');
    await meeting.waitFor('B', 'reconfirmed-1');
    await moveE1(moved2, '2');
    await meeting.waitFor('B', 'reconfirmed-2');

    // Remove the booked second date of E2: a cancellation, not a hide.
    final CreateDraftEntity current = (await repoE2.loadDraft(
      'user-creator-e2',
    ))!;
    final CreateDraftEntity removed = coordinator.apply(
      current,
      current.eventData!.copyWith(multiDateLocalDates: <String>[d1]),
    );
    expect(
      removed.eventData!.occurrences.single.id,
      e2.eventData!.occurrences.first.id,
    );
    await repoE2.saveDraft('user-creator-e2', removed);
    await meeting.arrive('resubmitted-3', <String, Object?>{
      'submissionIds': <String>[await submit(p2)],
    });
    await meeting.waitFor('gate', 'approved-3');
    await publish(p2);
    await meeting.arrive('removed');
    await meeting.waitFor('B', 'done');
  }

  Future<void> participant(E2Rendezvous meeting) async {
    final Map<String, Object?> published = await meeting.waitFor(
      'A',
      'published',
    );
    final BookingTransportRuntime runtime = await runtimeFor('viewer', 'B');
    final gateway = BookingTransportEventBookingGateway(
      adapter: runtime.adapter!,
      port: runtime.port!,
      gate: BookingTestEntryGuard(
        flag: true,
        releaseMode: false,
        binding: binding(),
      ),
    );
    final NotificationsInboxTestEntryGuard inboxGuard =
        NotificationsInboxTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: binding(),
        );
    final ServerNotificationsRepository inbox = ServerNotificationsRepository(
      port: BookingPortNotificationsAdapter(
        runtime: () async => runtime,
        guard: inboxGuard,
      ),
    );
    Future<List<NotificationItemEntity>> items() =>
        inbox.getNotifications(userId: 'not-sent');

    Future<EventBookingController> controllerFor(
      String eventId,
      String occurrenceId,
      String name,
    ) async {
      // The app takes the channel from the Catalog booking ref (the E2 gate
      // covers that path); an onsite Create Event is offered on 'onsite'.
      final EventBookingTerms terms = (await eventually(
        () => gateway.termsFor(
          eventId: eventId,
          occurrenceId: occurrenceId,
          channel: 'onsite',
        ),
        (EventBookingTermsResult result) => result.terms?.open ?? false,
        what: 'Booking terms of $name',
        detail: (EventBookingTermsResult result) =>
            '${result.outcome.name} ${result.code}',
      )).terms!;
      expect(terms.channel, 'onsite');
      final EventBookingController controller = EventBookingController(
        gateway: gateway,
        store: FileEventBookingOperationStore(
          File('${temp.path}/journal-$name.json'),
        ),
        occurrenceId: terms.occurrenceId,
        inventoryPoolId: terms.inventoryPoolId,
        channel: terms.channel,
        eventRevision: terms.eventRevision,
        maxParticipantUnits: terms.maxParticipantUnits,
      );
      await controller.load();
      return controller;
    }

    final String e1Occurrence = published['e1Occurrence']! as String;
    final EventBookingController e1 = await controllerFor(
      published['e1']! as String,
      e1Occurrence,
      'e1',
    );
    expect(e1.state.maxSeats, 2, reason: 'plus-one guest policy');
    e1.selectSeats(3);
    expect(e1.state.seats, 2, reason: 'the selector stays within the terms');
    await e1.book();
    final EventBookingView booked = e1.state.booking!;
    expect(booked.participantUnits, 2);
    final String e2Booked =
        (published['e2Occurrences']! as List<Object?>)[1]! as String;
    final EventBookingController e2 = await controllerFor(
      published['e2']! as String,
      e2Booked,
      'e2',
    );
    await e2.book();
    expect(e2.state.booking?.isActive, isTrue);
    await meeting.arrive('booked');

    Future<EventBookingView> requiredAfter(String point, int? previous) async {
      await meeting.waitFor('A', 'rescheduled-$point');
      return (await eventually<EventBookingView?>(
        () async {
          await e1.refresh();
          return e1.state.booking;
        },
        (EventBookingView? view) =>
            view != null &&
            view.reconfirmationRequired &&
            view.reconfirmationRequiredForRevision != previous,
        what: 'reconfirmation required after reschedule $point',
      ))!;
    }

    final EventBookingView first = await requiredAfter('1', null);
    expect(first.id, booked.id, reason: 'the Booking keeps its id');
    expect(
      first.occurrenceId,
      e1Occurrence,
      reason: 'the occurrence keeps its id',
    );
    expect(first.participantUnits, 2, reason: 'allocation kept');
    expect(e1.state.canCancel, isTrue, reason: 'cancel stays available');
    await eventually(
      items,
      (List<NotificationItemEntity> list) => list.any(
        (NotificationItemEntity item) => item.title == 'Подтвердите участие',
      ),
      what: 'the reconfirmation notice in the inbox',
    );
    await e1.reconfirm();
    expect(
      e1.state.booking?.reconfirmationState,
      EventReconfirmationState.confirmed,
    );
    await meeting.arrive('reconfirmed-1');

    final EventBookingView second = await requiredAfter(
      '2',
      first.reconfirmationRequiredForRevision,
    );
    expect(second.id, booked.id);
    final EventBookingResult stale = await gateway.execute(
      EventBookingOperation(
        kind: EventBookingOperationKind.reconfirm,
        idempotencyKey: 'f2-stale-${const Uuid().v4()}',
        occurrenceId: e1Occurrence,
        bookingId: second.id,
        expectedBookingRevision: second.revision,
        materialRevision: first.reconfirmationRequiredForRevision,
      ),
    );
    expect(stale.outcome, EventBookingOutcome.rejected);
    expect(stale.refusalCode, 'material_revision_mismatch');
    await e1.refresh();
    expect(e1.state.booking?.reconfirmationRequired, isTrue);
    await e1.reconfirm();
    expect(
      e1.state.booking?.reconfirmationState,
      EventReconfirmationState.confirmed,
    );
    await meeting.arrive('reconfirmed-2');

    await meeting.waitFor('A', 'removed');
    await eventually(
      () async {
        await e2.refresh();
        return e2.state;
      },
      (EventBookingViewState state) =>
          state.booking == null &&
          (state.message ?? '').contains('organizer cancelled this event'),
      what: 'the cancellation of the removed date',
    );
    await eventually(
      items,
      (List<NotificationItemEntity> list) => list.any(
        (NotificationItemEntity item) => item.title == 'Событие отменено',
      ),
      what: 'the cancellation notice in the inbox',
    );
    final List<NotificationItemEntity> all = await items();
    expect(
      all.map((NotificationItemEntity item) => item.id).toSet(),
      hasLength(all.length),
      reason: 'no duplicate inbox record',
    );
    await meeting.arrive('done');
  }

  test(
    'F2 client: reschedule through Create, reconfirm, stale answer, removed date',
    () async {
      final E2Rendezvous meeting = rendezvous!;
      if (meeting.role == 'A') {
        await organizer(meeting);
      } else {
        await participant(meeting);
      }
    },
    skip: skip ? StandBackend.skipReason : false,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

/// Every request on a fresh connection (see the B2 keep-alive note).
final class _FreshConnectionClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.persistentConnection = false;
    return _inner.send(request);
  }
}
