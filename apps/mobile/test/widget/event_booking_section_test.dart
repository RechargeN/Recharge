import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';
import 'package:recharge/features/booking/application/event_booking_controller.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';
import 'package:recharge/features/booking/presentation/event_booking_section.dart';
import '../support/l10n/l10n_screenshot.dart';

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
  Locale? locale,
  double textScale = 1,
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
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: EventBookingSection(
            controller: controller,
            eventTimeZoneId: 'Europe/Riga',
          ),
        ),
      ),
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
    expect(find.text('1 of 2 seats'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-booking-seats-more')));
    await tester.pump();
    expect(find.text('2 of 2 seats'), findsOneWidget);
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

  group('L4: lv, en and ru on one Booking', () {
    final DateTime deadline = DateTime.utc(2026, 10, 25, 1, 30);
    EventBookingView required() => EventBookingView(
      id: 'b-1',
      occurrenceId: 'occ-1',
      state: EventBookingState.confirmed,
      participantUnits: 2,
      revision: 2,
      reconfirmationState: EventReconfirmationState.required,
      reconfirmationRequiredForRevision: 8,
      reconfirmationDeadlineUtc: deadline,
    );

    const Map<String, (String, String, String)> expected =
        <String, (String, String, String)>{
          // (deadline wall clock in Riga, a refusal, the cancel action)
          'en': ('3:30', 'This event is sold out.', 'Cancel booking'),
          'lv': (
            '03:30',
            'Šim pasākumam vairs nav brīvu vietu.',
            'Atcelt rezervāciju',
          ),
          'ru': ('03:30', 'На это событие мест больше нет.', 'Отменить бронь'),
        };

    for (final MapEntry<String, (String, String, String)> language
        in expected.entries) {
      for (final double scale in <double>[1, 2]) {
        testWidgets(
          '${language.key} at 360 dp, text x$scale: localized, in the Event '
          'zone, nothing overflows or is cut off',
          (WidgetTester tester) async {
            tester.view.physicalSize = const Size(360, 720);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final _Gateway gateway = _Gateway()..active = required();
            final EventBookingController controller = await _pump(
              tester,
              gateway,
              locale: Locale(language.key),
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            await l10nCaptureScreen(tester);
            // The deadline is the same instant, shown in Riga wall time
            // (the DST fall-back hour) in every language.
            expect(find.textContaining(language.value.$1), findsOneWidget);
            final Finder cancel = find.text(language.value.$3);
            expect(cancel, findsOneWidget);
            await tester.ensureVisible(cancel);
            expect(cancel.hitTestable(), findsOneWidget);
            // Domain facts are untouched by the language.
            expect(controller.state.booking!.id, 'b-1');
            expect(
              controller.state.booking!.reconfirmationDeadlineUtc,
              deadline,
            );
            expect(controller.occurrenceId, 'occ-1');

            gateway
              ..active = null
              ..next = const EventBookingResult(
                EventBookingOutcome.rejected,
                refusalCode: 'sold_out',
              );
            await tester.tap(find.byKey(const Key('event-booking-refresh')));
            await tester.pump();
            await tester.pump();
            await tester.ensureVisible(
              find.byKey(const Key('event-booking-create')),
            );
            await tester.tap(find.byKey(const Key('event-booking-create')));
            await tester.pump();
            await tester.pump();
            expect(find.text(language.value.$2), findsOneWidget);
            expect(find.textContaining('sold_out'), findsNothing);
            expect(controller.state.message!.refusalCode, 'sold_out');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('an unknown refusal code shows the safe generic text', (
      WidgetTester tester,
    ) async {
      final _Gateway gateway = _Gateway()
        ..next = const EventBookingResult(
          EventBookingOutcome.rejected,
          refusalCode: 'waitlist_offer_expired',
        );
      await _pump(tester, gateway, locale: const Locale('lv'));
      await tester.tap(find.byKey(const Key('event-booking-create')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Rezervācija netika pieņemta.'), findsOneWidget);
      expect(find.textContaining('waitlist_offer_expired'), findsNothing);
    });
  });
}
