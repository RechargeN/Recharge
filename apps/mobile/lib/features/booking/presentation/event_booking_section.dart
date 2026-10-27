import 'package:flutter/material.dart';

import '../../../core/localization/l10n_context.dart';
import '../../../core/localization/recharge_formats.dart';
import '../../../core/localization/user_message_catalog.dart';
import '../application/event_booking_controller.dart';
import '../domain/repositories/event_booking_gateway.dart';

/// Booking panel for one Event occurrence. It renders only what the controller
/// reports; it holds no Booking state of its own.
class EventBookingSection extends StatelessWidget {
  const EventBookingSection({
    super.key,
    required this.controller,
    required this.eventTimeZoneId,
  });

  final EventBookingController controller;

  /// L4: the Event's own IANA zone; Booking times are shown in it, never in
  /// the device zone, whatever the UI language.
  final String eventTimeZoneId;

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
                    context.l10n.bookingTitle,
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
    final AppLocalizations l10n = context.l10n;
    final EventBookingView? booking = state.booking;
    final EventBookingMessage? message = state.message;
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
              Expanded(
                child: Text(
                  state.phase == EventBookingPhase.loading
                      ? l10n.bookingLoading
                      : l10n.bookingSending,
                  key: const Key('event-booking-busy'),
                ),
              ),
            ],
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              bookingMessageText(l10n, message),
              key: const Key('event-booking-message'),
            ),
          ),
        if (booking != null && booking.isActive)
          Text(
            l10n.bookingMine(
              l10n.bookingStatus(booking.state.name),
              l10n.bookingSeatsCount(booking.participantUnits),
            ),
            key: const Key('event-booking-mine'),
          )
        else if (!busy && state.phase == EventBookingPhase.ready)
          Text(l10n.bookingNone),
        if (booking != null && booking.reconfirmationRequired)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _deadlineText(context, booking.reconfirmationDeadlineUtc),
              key: const Key('event-booking-reconfirm-required'),
            ),
          ),
        if (state.canBook && state.maxSeats > 1)
          Row(
            children: <Widget>[
              IconButton(
                key: const Key('event-booking-seats-less'),
                tooltip: l10n.bookingFewerSeats,
                onPressed: state.seats > 1
                    ? () => controller.selectSeats(state.seats - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Flexible(
                child: Text(
                  l10n.bookingSeatsSelector(state.seats, state.maxSeats),
                  key: const Key('event-booking-seats'),
                ),
              ),
              IconButton(
                key: const Key('event-booking-seats-more'),
                tooltip: l10n.bookingMoreSeats,
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
                child: Text(l10n.bookingBookSeats(state.seats)),
              ),
            if (state.canReconfirm)
              FilledButton(
                key: const Key('event-booking-reconfirm'),
                onPressed: controller.reconfirm,
                child: Text(l10n.bookingConfirmAttendance),
              ),
            if (state.canCancel)
              OutlinedButton(
                key: const Key('event-booking-cancel'),
                onPressed: controller.cancel,
                child: Text(l10n.bookingCancel),
              ),
            if (state.canRetry)
              OutlinedButton(
                key: const Key('event-booking-retry'),
                onPressed: controller.retry,
                child: Text(
                  state.phase == EventBookingPhase.unknownOutcome
                      ? l10n.commonCheckAgain
                      : l10n.commonRetry,
                ),
              ),
            if (state.canRefresh)
              TextButton(
                key: const Key('event-booking-refresh'),
                onPressed: controller.refresh,
                child: Text(l10n.commonRefresh),
              ),
          ],
        ),
      ],
    );
  }

  String _deadlineText(BuildContext context, DateTime? deadlineUtc) {
    final AppLocalizations l10n = context.l10n;
    if (deadlineUtc == null) return l10n.bookingReconfirmRequired;
    return l10n.bookingReconfirmBy(
      RechargeFormats.dateTime(deadlineUtc, eventTimeZoneId, l10n.localeName),
    );
  }
}

/// L4: a Booking notice as localized text. A server refusal goes through the
/// shared catalog, so an unknown code gets the safe generic text.
String bookingMessageText(AppLocalizations l10n, EventBookingMessage message) =>
    switch (message.notice) {
      EventBookingNotice.offline => l10n.errorOffline,
      EventBookingNotice.offlineSaved => l10n.errorOfflineSaved,
      EventBookingNotice.unknownOutcome => l10n.errorUnknownOutcome,
      EventBookingNotice.sessionNotConfirmed => l10n.errorSessionNotConfirmed,
      EventBookingNotice.loadFailed => l10n.bookingErrorLoadFailed,
      EventBookingNotice.rateLimited =>
        message.retryAfterSeconds == null
            ? l10n.errorRateLimited
            : l10n.errorRateLimitedSeconds(message.retryAfterSeconds!),
      EventBookingNotice.refused => UserMessageCatalog.booking(
        l10n,
        message.refusalCode,
      ),
      EventBookingNotice.endedMissedReconfirmation =>
        l10n.bookingEndedMissedReconfirmation,
      EventBookingNotice.endedEventCancelled => l10n.bookingEndedEventCancelled,
      EventBookingNotice.endedOrganizerCancelled =>
        l10n.bookingEndedOrganizerCancelled,
    };
