import 'package:flutter/material.dart';

import '../application/event_booking_controller.dart';
import '../domain/repositories/event_booking_gateway.dart';

/// Booking panel for one Event occurrence. It renders only what the controller
/// reports; it holds no Booking state of its own.
class EventBookingSection extends StatelessWidget {
  const EventBookingSection({super.key, required this.controller});

  final EventBookingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final EventBookingViewState state = controller.state;
        return Material(
          elevation: 4,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Booking',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _body(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, EventBookingViewState state) {
    final EventBookingView? booking = state.booking;
    final bool busy =
        state.phase == EventBookingPhase.loading ||
        state.phase == EventBookingPhase.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (busy)
          Row(
            children: <Widget>[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                state.phase == EventBookingPhase.loading
                    ? 'Loading your booking...'
                    : 'Sending your request...',
                key: const Key('event-booking-busy'),
              ),
            ],
          ),
        if (state.message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              state.message!,
              key: const Key('event-booking-message'),
            ),
          ),
        if (booking != null && booking.isActive)
          Text(
            'Your booking: ${booking.state.name}, '
            '${booking.participantUnits} seat(s)',
            key: const Key('event-booking-mine'),
          )
        else if (!busy && state.phase == EventBookingPhase.ready)
          const Text('You have no booking for this event.'),
        if (booking != null && booking.reconfirmationRequired)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _deadlineText(booking.reconfirmationDeadlineUtc),
              key: const Key('event-booking-reconfirm-required'),
            ),
          ),
        if (state.canBook && state.maxSeats > 1)
          Row(
            children: <Widget>[
              IconButton(
                key: const Key('event-booking-seats-less'),
                onPressed: state.seats > 1
                    ? () => controller.selectSeats(state.seats - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                '${state.seats} of ${state.maxSeats} seat(s)',
                key: const Key('event-booking-seats'),
              ),
              IconButton(
                key: const Key('event-booking-seats-more'),
                onPressed: state.seats < state.maxSeats
                    ? () => controller.selectSeats(state.seats + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (state.canBook || busy)
              FilledButton(
                key: const Key('event-booking-create'),
                onPressed: state.canBook ? controller.book : null,
                child: Text(
                  state.seats == 1
                      ? 'Book 1 seat'
                      : 'Book ${state.seats} seats',
                ),
              ),
            if (state.canReconfirm)
              FilledButton(
                key: const Key('event-booking-reconfirm'),
                onPressed: controller.reconfirm,
                child: const Text('Confirm attendance'),
              ),
            if (state.canCancel)
              OutlinedButton(
                key: const Key('event-booking-cancel'),
                onPressed: controller.cancel,
                child: const Text('Cancel booking'),
              ),
            if (state.canRetry)
              OutlinedButton(
                key: const Key('event-booking-retry'),
                onPressed: controller.retry,
                child: Text(
                  state.phase == EventBookingPhase.unknownOutcome
                      ? 'Check again'
                      : 'Try again',
                ),
              ),
            if (state.canRefresh)
              TextButton(
                key: const Key('event-booking-refresh'),
                onPressed: controller.refresh,
                child: const Text('Refresh'),
              ),
          ],
        ),
      ],
    );
  }

  static String _deadlineText(DateTime? deadlineUtc) {
    if (deadlineUtc == null) {
      return 'The event changed. Please confirm your attendance.';
    }
    final DateTime local = deadlineUtc.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'The event changed. Confirm your attendance by '
        '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}.';
  }
}
