import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/application/event_booking_controller.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';
import 'package:recharge/features/booking/presentation/event_booking_section.dart';

final class _Gateway implements EventBookingGateway {
  EventBookingView? active;
  final List<EventBookingOperation> executed = <EventBookingOperation>[];
  EventBookingResult? next;

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
    executed.add(operation);
    final EventBookingResult? planned = next;
    next = null;
    if (planned != null) return planned;
    if (operation.kind == EventBookingOperationKind.reconfirm) {
      active = EventBookingView(
        id: 'b-1',
        occurrenceId: 'occ-1',
        state: EventBookingState.confirmed,
        participantUnits: 2,
        revision: 3,
        reconfirmationState: EventReconfirmationState.confirmed,
      );
    }
    return EventBookingResult(EventBookingOutcome.succeeded, booking: active);
  }

  @override
  Future<EventBookingResult> booking(String bookingId) async =>
      const EventBookingResult(EventBookingOutcome.succeeded);
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

Future<EventBookingController> _pump(
  WidgetTester tester,
  _Gateway gateway, {
  int maxSeats = 1,
}) async {
  final EventBookingController controller = EventBookingController(
    gateway: gateway,
    store: _Store(),
    occurrenceId: 'occ-1',
    inventoryPoolId: 'pool',
    channel: 'onsite',
    eventRevision: 7,
    maxParticipantUnits: maxSeats,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: EventBookingSection(controller: controller)),
    ),
  );
  await controller.load();
  await tester.pump();
  return controller;
}

void main() {
  testWidgets(
    'required reconfirmation shows its deadline, confirm and cancel',
    (WidgetTester tester) async {
      final _Gateway gateway = _Gateway()
        ..active = EventBookingView(
          id: 'b-1',
          occurrenceId: 'occ-1',
          state: EventBookingState.confirmed,
          participantUnits: 2,
          revision: 2,
          reconfirmationState: EventReconfirmationState.required,
          reconfirmationRequiredForRevision: 8,
          reconfirmationDeadlineUtc: DateTime.utc(2026, 11, 12, 17),
        );
      await _pump(tester, gateway);
      expect(
        find.byKey(const Key('event-booking-reconfirm-required')),
        findsOneWidget,
      );
      expect(find.textContaining('Confirm your attendance by'), findsOneWidget);
      expect(find.byKey(const Key('event-booking-cancel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('event-booking-reconfirm')));
      await tester.pump();
      await tester.pump();
      expect(gateway.executed.single.materialRevision, 8);
      expect(find.byKey(const Key('event-booking-reconfirm')), findsNothing);
      expect(
        find.byKey(const Key('event-booking-reconfirm-required')),
        findsNothing,
      );
    },
  );

  testWidgets('the seat selector stays within the terms limit', (
    WidgetTester tester,
  ) async {
    final _Gateway gateway = _Gateway();
    await _pump(tester, gateway, maxSeats: 2);
    expect(find.text('1 of 2 seat(s)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-booking-seats-more')));
    await tester.pump();
    expect(find.text('2 of 2 seat(s)'), findsOneWidget);
    expect(find.text('Book 2 seats'), findsOneWidget);
    final IconButton more = tester.widget<IconButton>(
      find.byKey(const Key('event-booking-seats-more')),
    );
    expect(more.onPressed, isNull);
    await tester.tap(find.byKey(const Key('event-booking-create')));
    await tester.pump();
    await tester.pump();
    expect(gateway.executed.single.participantUnits, 2);
  });

  testWidgets('one seat keeps the single-seat layout used by B2', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _Gateway());
    expect(find.byKey(const Key('event-booking-seats')), findsNothing);
    expect(find.text('Book 1 seat'), findsOneWidget);
    expect(find.byKey(const Key('event-booking-refresh')), findsOneWidget);
  });

  testWidgets('a refusal is explained, and refresh re-reads the server', (
    WidgetTester tester,
  ) async {
    final _Gateway gateway = _Gateway()
      ..next = const EventBookingResult(
        EventBookingOutcome.rejected,
        refusalCode: 'sold_out',
      );
    await _pump(tester, gateway);
    await tester.tap(find.byKey(const Key('event-booking-create')));
    await tester.pump();
    await tester.pump();
    expect(find.text('This event is sold out.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-booking-refresh')));
    await tester.pump();
    await tester.pump();
    expect(find.text('This event is sold out.'), findsNothing);
    expect(find.byKey(const Key('event-booking-create')), findsOneWidget);
  });
}
