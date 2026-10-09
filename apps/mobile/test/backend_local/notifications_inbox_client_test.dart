import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/booking_test_entry_guard.dart';
import 'package:recharge/app/di/notifications_inbox_composition.dart';
import 'package:recharge/app/testing/seeded_event_fixture.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_event_booking_gateway.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';
import 'package:recharge/features/notifications/data/remote/notifications_inbox_port.dart';
import 'package:recharge/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:recharge/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:uuid/uuid.dart';

import 'support/stand_backend.dart';

/// F1 client, started by `stand-f1-gate.mjs` after it enabled the default-off
/// F1 flags. Books the seeded Event through the real Booking adapter, reads the
/// server inbox through the real Notifications adapter and Session, then
/// cancels while the stand makes Notifications state unreadable: the
/// cancellation still completes, and after repair exactly one record per
/// effect appears. Operator steps run on the stand, never in the client.
///
/// Limits: PC host against the local Emulator; no push, no device, no cloud.
void main() {
  final StandBackend? stand = StandBackend.fromEnvironment();
  final bool skip = stand == null;
  const String label = 'staff';
  late Directory temp;

  BookingBackendBindingController binding() => BookingBackendBindingController(
    emulatorBase: StandBackend.functionsBase,
    releaseMode: false,
    initial: BackendBindingMode.testBackend,
  );

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
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  setUpAll(() async {
    if (skip) return;
    temp = await Directory.systemTemp.createTemp('f1-client-');
  });

  tearDownAll(() async {
    if (!skip && await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'F1 client: Booking effects reach the server inbox once; an unreadable '
    'Notifications state never blocks cancellation',
    () async {
      final sessions = FileSessionStore(File('${temp.path}/session.json'));
      final BookingTransportRuntime runtime =
          await BookingTransportRuntimeFactory(
            endpoint: binding().endpoint,
            client: CountingClient(),
            tokens: AuthEmulatorTokenProvider('stand-user-$label'),
            sessions: sessions,
            installations: const FixedInstallationId('f1-installation-staff'),
            supportDirectory: () async =>
                Directory('${temp.path}/support').create(recursive: true),
          ).create();
      try {
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
      } on BookingCallableFailure catch (error) {
        fail('establish failed with ${error.code}');
      }

      // The test entry is the only way to the server inbox.
      final NotificationsRepository disabled = notificationsRepositoryFor(
        manifest: notificationsBindingManifest(
          NotificationsInboxTestEntryGuard(
            flag: false,
            releaseMode: false,
            binding: binding(),
          ),
        ),
        local: () => const DisabledNotificationsRepository(),
        port: BookingPortNotificationsAdapter(
          runtime: () async => runtime,
          guard: NotificationsInboxTestEntryGuard(
            flag: false,
            releaseMode: false,
            binding: binding(),
          ),
        ),
      );
      await expectLater(
        disabled.getNotifications(userId: 'ignored'),
        throwsA(isA<NotificationsInboxFailure>()),
      );

      final NotificationsInboxTestEntryGuard guard =
          NotificationsInboxTestEntryGuard(
            flag: true,
            releaseMode: false,
            binding: binding(),
          );
      final NotificationsRepository inbox = notificationsRepositoryFor(
        manifest: notificationsBindingManifest(guard),
        local: () => fail('the local inbox must not be used'),
        port: BookingPortNotificationsAdapter(
          runtime: () async => runtime,
          guard: guard,
        ),
      );
      Future<List<NotificationItemEntity>> items() =>
          inbox.getNotifications(userId: 'not-sent-to-the-server');

      // 1. Book the seeded Event; a repeated command makes no second Booking.
      final gateway = BookingTransportEventBookingGateway(
        adapter: runtime.adapter!,
        port: runtime.port!,
        gate: BookingTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: binding(),
        ),
      );
      final String key = 'f1-${const Uuid().v4()}';
      final EventBookingOperation create = EventBookingOperation(
        kind: EventBookingOperationKind.create,
        idempotencyKey: key,
        occurrenceId: seededBookingOccurrenceId,
        inventoryPoolId: seededBookingPoolId,
        channel: seededBookingChannel,
        participantUnits: 1,
        eventRevision: seededBookingEventRevision,
      );
      final EventBookingResult first = await gateway.execute(create);
      final EventBookingResult repeated = await gateway.execute(create);
      expect(first.outcome, EventBookingOutcome.succeeded);
      expect(repeated.booking?.id, first.booking?.id);
      final String bookingId = first.booking!.id;

      final List<NotificationItemEntity> confirmed = await eventually(
        items,
        (List<NotificationItemEntity> value) => value.isNotEmpty,
        what: 'the confirmation record',
      );
      expect(confirmed, hasLength(1), reason: 'one record per effect');
      expect(confirmed.single.title, 'Бронь подтверждена');
      expect(confirmed.single.isRead, isFalse);
      expect(confirmed.single.subjectRef?.id, seededBookingEventId);

      // 2. Notifications state becomes unreadable; cancellation still works.
      await stand!.notifications(<String>['prefs-corrupt', label]);
      final EventBookingResult cancelled = await gateway.execute(
        EventBookingOperation(
          kind: EventBookingOperationKind.cancel,
          idempotencyKey: '$key-cancel',
          occurrenceId: seededBookingOccurrenceId,
          bookingId: bookingId,
          expectedBookingRevision: first.booking!.revision,
        ),
      );
      expect(cancelled.outcome, EventBookingOutcome.succeeded);
      expect(cancelled.booking?.isActive, isFalse);
      final Map<String, Object?> pending = await eventually(
        () => stand.notifications(<String>['receipt', '${bookingId}__r2']),
        (Map<String, Object?> value) => value['status'] == 'retry_scheduled',
        what: 'the failed cancellation attempt, recorded for retry',
      );
      expect(pending['attemptCount'], 1);

      // 3. Repair; reconciliation creates exactly one cancellation record.
      await stand.notifications(<String>['prefs-repair', label]);
      await eventually(
        () => stand.notifications(<String>['reconcile']),
        (Map<String, Object?> report) => report['complete'] == true,
        what: 'a complete reconciliation',
      );
      final List<NotificationItemEntity> both = await items();
      expect(
        both.map((NotificationItemEntity item) => item.title).toList(),
        <String>['Бронь отменена', 'Бронь подтверждена'],
      );
      expect(
        both.map((NotificationItemEntity item) => item.id).toSet(),
        hasLength(2),
      );

      // 4. Read state is server-authoritative and idempotent.
      final String confirmationId = both.last.id;
      await inbox.markNotificationRead(
        userId: 'ignored',
        notificationId: confirmationId,
      );
      await inbox.markNotificationRead(
        userId: 'ignored',
        notificationId: confirmationId,
      );
      final List<NotificationItemEntity> after = await items();
      expect(
        after
            .firstWhere(
              (NotificationItemEntity item) => item.id == confirmationId,
            )
            .isRead,
        isTrue,
      );
      expect(
        after.where((NotificationItemEntity item) => !item.isRead),
        hasLength(1),
      );
    },
    skip: skip ? StandBackend.skipReason : false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
