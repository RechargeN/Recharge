import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/application/event_booking_controller.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';

void main() {
  late _Store store;
  late _Gateway gateway;

  EventBookingController controller() => EventBookingController(
    gateway: gateway,
    store: store,
    occurrenceId: 'occ-1',
    inventoryPoolId: 'pool',
    channel: 'onsite',
    eventRevision: 1,
  );

  setUp(() {
    store = _Store();
    gateway = _Gateway();
  });

  test(
    'unlimited capacity sends neither pool nor channel (E2b terms)',
    () async {
      final c = EventBookingController(
        gateway: gateway,
        store: store,
        occurrenceId: 'occ-1',
        inventoryPoolId: null,
        channel: null,
        eventRevision: 3,
      );
      await c.load();
      await c.book();
      final EventBookingOperation sent = gateway.executed.single;
      expect(sent.inventoryPoolId, isNull);
      expect(sent.channel, isNull);
      expect(sent.eventRevision, 3);
      expect(sent.toJson().containsKey('inventoryPoolId'), isFalse);
    },
  );

  test('a double tap is one intent: one journal entry, one command', () async {
    final c = controller();
    await c.load();

    final first = c.book();
    final second = c.book();
    await Future.wait(<Future<void>>[first, second]);

    expect(gateway.executed, hasLength(1));
    expect(c.state.booking?.isActive, isTrue);
    expect(store.pending, isNull, reason: 'cleared after success');
  });

  test('the intent is journaled before the first dispatch', () async {
    final c = controller();
    await c.load();
    gateway.beforeExecute = () => expect(store.pending, isNotNull);

    await c.book();

    expect(gateway.executed, hasLength(1));
  });

  test('unknown outcome keeps the key; checking again replays it', () async {
    final c = controller();
    await c.load();
    gateway.next.add(
      const EventBookingResult(EventBookingOutcome.unknownOutcome),
    );

    await c.book();
    expect(c.state.phase, EventBookingPhase.unknownOutcome);
    expect(c.state.canBook, isFalse, reason: 'no new command while unknown');
    final key = store.pending!.idempotencyKey;

    await c.retry();

    expect(gateway.executed.map((o) => o.idempotencyKey), <String>[key, key]);
    expect(c.state.booking?.isActive, isTrue);
  });

  test(
    'a restart replays the journaled intent with its original key',
    () async {
      final first = controller();
      await first.load();
      gateway.next.add(
        const EventBookingResult(EventBookingOutcome.unknownOutcome),
      );
      await first.book();
      final key = store.pending!.idempotencyKey;

      final restarted = controller();
      await restarted.load();

      expect(gateway.executed.last.idempotencyKey, key);
      expect(restarted.state.booking?.isActive, isTrue);
      expect(store.pending, isNull);
    },
  );

  test('offline keeps the saved request and never duplicates it', () async {
    final c = controller();
    await c.load();
    gateway.next.add(const EventBookingResult(EventBookingOutcome.offline));

    await c.book();
    expect(c.state.phase, EventBookingPhase.offline);
    expect(c.state.hasPendingOperation, isTrue);

    await c.retry();
    expect(gateway.executed, hasLength(2));
    expect(
      gateway.executed.first.idempotencyKey,
      gateway.executed.last.idempotencyKey,
    );
  });

  test(
    'a final refusal clears the intent and lets the user start over',
    () async {
      final c = controller();
      await c.load();
      gateway.next.add(const EventBookingResult(EventBookingOutcome.rejected));

      await c.book();

      expect(c.state.phase, EventBookingPhase.error);
      expect(store.pending, isNull);
      await c.retry();
      expect(c.state.canBook, isTrue);
    },
  );

  test('cancel is journaled with the confirmed revision and clears', () async {
    final c = controller();
    await c.load();
    await c.book();
    expect(c.state.canCancel, isTrue);

    await c.cancel();

    expect(gateway.executed.last.kind, EventBookingOperationKind.cancel);
    expect(gateway.executed.last.expectedBookingRevision, 1);
    expect(c.state.booking, isNull);
    expect(store.pending, isNull);
  });

  EventBookingView required({int revision = 2, int material = 8}) =>
      EventBookingView(
        id: 'b-1',
        occurrenceId: 'occ-1',
        state: EventBookingState.confirmed,
        participantUnits: 1,
        revision: revision,
        reconfirmationState: EventReconfirmationState.required,
        reconfirmationRequiredForRevision: material,
        reconfirmationDeadlineUtc: DateTime.utc(2026, 11, 12, 17),
      );

  test(
    'F2: reconfirm is journaled with the exact revisions and replays its key',
    () async {
      gateway.active = required();
      final c = controller();
      await c.load();
      expect(c.state.canReconfirm, isTrue);
      expect(c.state.canCancel, isTrue, reason: 'cancel stays available');
      gateway.next.add(
        const EventBookingResult(EventBookingOutcome.unknownOutcome),
      );

      await c.reconfirm();
      final EventBookingOperation sent = gateway.executed.single;
      expect(sent.kind, EventBookingOperationKind.reconfirm);
      expect(sent.bookingId, 'b-1');
      expect(sent.expectedBookingRevision, 2);
      expect(sent.materialRevision, 8);
      expect(store.pending?.toJson()['materialRevision'], 8);
      expect(c.state.canReconfirm, isFalse, reason: 'no second intent');

      // A restart replays the same intent; the server confirms it once.
      final restarted = controller();
      await restarted.load();
      expect(gateway.executed.last.idempotencyKey, sent.idempotencyKey);
      expect(
        restarted.state.booking?.reconfirmationState,
        EventReconfirmationState.confirmed,
      );
      expect(store.pending, isNull);
    },
  );

  test(
    'F2: typed refusals become specific messages; unknown stays general',
    () async {
      final c = controller();
      await c.load();
      for (final (String code, String text) in <(String, String)>[
        ('sold_out', 'This event is sold out.'),
        (
          'active_booking_limit_reached',
          'You have reached the limit of active bookings.',
        ),
        ('registration_closed', 'Registration is closed.'),
        (
          'reconfirmation_deadline_passed',
          'The confirmation deadline has passed.',
        ),
        (
          'material_revision_mismatch',
          'The event changed again. Refresh and confirm the new time.',
        ),
        ('something_new', 'The booking was not accepted.'),
      ]) {
        gateway.next.add(
          EventBookingResult(EventBookingOutcome.rejected, refusalCode: code),
        );
        await c.book();
        expect(c.state.message, text);
        expect(store.pending, isNull);
        await c.retry();
      }
    },
  );

  test(
    'F2: too many attempts keeps the saved intent and names the wait',
    () async {
      final c = controller();
      await c.load();
      gateway.next.add(
        const EventBookingResult(
          EventBookingOutcome.rateLimited,
          refusalCode: 'rate_limited',
          retryAfter: Duration(seconds: 30),
        ),
      );
      await c.book();
      expect(c.state.message, 'Too many attempts. Try again in 30 s.');
      expect(store.pending, isNotNull);
      await c.retry();
      expect(
        gateway.executed.map((o) => o.idempotencyKey).toSet(),
        hasLength(1),
      );
    },
  );

  test(
    'F2: seats stay within the terms limit and are sent with the intent',
    () async {
      final c = EventBookingController(
        gateway: gateway,
        store: store,
        occurrenceId: 'occ-1',
        inventoryPoolId: 'pool',
        channel: 'onsite',
        eventRevision: 1,
        maxParticipantUnits: 3,
      );
      await c.load();
      c.selectSeats(5);
      expect(c.state.seats, 3);
      c.selectSeats(0);
      expect(c.state.seats, 1);
      c.selectSeats(2);
      await c.book();
      expect(gateway.executed.single.participantUnits, 2);
    },
  );

  test('F2: refresh explains a Booking ended by a missed deadline', () async {
    gateway.active = required();
    final c = controller();
    await c.load();
    gateway.active = null;
    gateway.ended = EventBookingView(
      id: 'b-1',
      occurrenceId: 'occ-1',
      state: EventBookingState.cancelled,
      participantUnits: 1,
      revision: 3,
      reconfirmationState: EventReconfirmationState.missed,
      terminalReason: 'missedReconfirmation',
    );
    await c.refresh();
    expect(c.state.booking, isNull);
    expect(
      c.state.message,
      'Your booking was released because attendance was not confirmed in time.',
    );
    expect(c.state.canBook, isTrue);
  });
}

EventBookingView _view(EventBookingState state) => EventBookingView(
  id: 'b-1',
  occurrenceId: 'occ-1',
  state: state,
  participantUnits: 1,
  revision: 1,
);

final class _Gateway implements EventBookingGateway {
  EventBookingView? active;
  EventBookingView? ended;
  final List<EventBookingOperation> executed = <EventBookingOperation>[];
  final List<EventBookingResult> next = <EventBookingResult>[];
  void Function()? beforeExecute;

  @override
  Future<EventBookingResult> activeFor(String occurrenceId) async =>
      EventBookingResult(EventBookingOutcome.succeeded, booking: active);

  @override
  Future<EventBookingTermsResult> termsFor({
    required String eventId,
    required String occurrenceId,
    String? channel,
  }) async =>
      const EventBookingTermsResult(EventBookingTermsOutcome.unavailable);

  @override
  Future<EventBookingResult> execute(EventBookingOperation operation) async {
    beforeExecute?.call();
    executed.add(operation);
    await Future<void>.delayed(Duration.zero);
    if (next.isNotEmpty) return next.removeAt(0);
    active = switch (operation.kind) {
      EventBookingOperationKind.create => _view(EventBookingState.confirmed),
      EventBookingOperationKind.cancel => null,
      EventBookingOperationKind.reconfirm => EventBookingView(
        id: 'b-1',
        occurrenceId: 'occ-1',
        state: EventBookingState.confirmed,
        participantUnits: 1,
        revision: (operation.expectedBookingRevision ?? 1) + 1,
        reconfirmationState: EventReconfirmationState.confirmed,
      ),
    };
    return EventBookingResult(EventBookingOutcome.succeeded, booking: active);
  }

  @override
  Future<EventBookingResult> booking(String bookingId) async =>
      EventBookingResult(EventBookingOutcome.succeeded, booking: ended);
}

final class _Store implements EventBookingOperationStore {
  EventBookingOperation? pending;

  @override
  Future<EventBookingOperation?> read(String occurrenceId) async => pending;

  @override
  Future<void> write(EventBookingOperation operation) async =>
      pending = operation;

  @override
  Future<void> clear(String occurrenceId) async => pending = null;
}
