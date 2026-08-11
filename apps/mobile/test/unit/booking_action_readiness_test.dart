import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/domain/entities/booking.dart';
import 'package:recharge/features/booking/domain/entities/booking_action.dart';
import 'package:recharge/features/booking/domain/entities/booking_hold.dart';
import 'package:recharge/features/booking/domain/usecases/evaluate_booking_action_readiness_usecase.dart';

void main() {
  const evaluate = EvaluateBookingActionReadinessUseCase();
  final now = DateTime.utc(2026, 8, 9, 9, 30);

  test('terminal Booking blocks every action locally', () {
    final result = evaluate(
      booking: _booking(BookingState.cancelled),
      action: BookingAction.cancel,
      nowUtc: now,
    );
    expect(result.state, BookingActionReadinessState.blocked);
    expect(result.reason, BookingActionReadinessReason.bookingTerminal);
  });

  test('reconfirm is exposed only for confirmed required projection', () {
    final blocked = evaluate(
      booking: _booking(BookingState.confirmed),
      action: BookingAction.reconfirm,
      nowUtc: now,
    );
    expect(blocked.state, BookingActionReadinessState.blocked);

    final ready = evaluate(
      booking: _booking(
        BookingState.confirmed,
        reconfirmationState: BookingReconfirmationState.required,
      ),
      action: BookingAction.reconfirm,
      nowUtc: now,
    );
    expect(ready.state, BookingActionReadinessState.requiresServerCheck);
  });

  test('waitlist hold requires exact active non-expired reference', () {
    final booking = _booking(BookingState.waitlisted, activeHoldId: 'hold-1');
    final active = _hold(expiresAtUtc: DateTime.utc(2026, 8, 9, 10));
    expect(
      evaluate(
        booking: booking,
        action: BookingAction.acceptWaitlistHold,
        nowUtc: now,
        hold: active,
      ).state,
      BookingActionReadinessState.requiresServerCheck,
    );

    expect(
      evaluate(
        booking: booking,
        action: BookingAction.acceptWaitlistHold,
        nowUtc: now,
        hold: _hold(expiresAtUtc: DateTime.utc(2026, 8, 9, 9)),
      ).reason,
      BookingActionReadinessReason.holdExpiredLocally,
    );
  });

  test('Creator approval is structurally relevant only to application', () {
    expect(
      evaluate(
        booking: _booking(
          BookingState.pending,
          admissionMode: BookingAdmissionMode.application,
        ),
        action: BookingAction.approveApplication,
        nowUtc: now,
      ).state,
      BookingActionReadinessState.requiresServerCheck,
    );
    expect(
      evaluate(
        booking: _booking(BookingState.confirmed),
        action: BookingAction.approveApplication,
        nowUtc: now,
      ).state,
      BookingActionReadinessState.blocked,
    );
  });
}

Booking _booking(
  BookingState state, {
  BookingAdmissionMode admissionMode = BookingAdmissionMode.booking,
  BookingReconfirmationState reconfirmationState =
      BookingReconfirmationState.notRequired,
  String? activeHoldId,
}) {
  final terminal = state == BookingState.cancelled;
  return Booking(
    schemaVersion: 1,
    id: 'booking-1',
    revision: 1,
    userId: 'user-1',
    eventId: 'event-1',
    occurrenceId: 'occurrence-1',
    inventoryPoolId: 'pool-1',
    channel: BookingChannel.onsite,
    admissionMode: admissionMode,
    confirmationMode: admissionMode == BookingAdmissionMode.application
        ? BookingConfirmationMode.manualApproval
        : BookingConfirmationMode.instant,
    state: state,
    participantUnits: 1,
    namedGuestCount: 0,
    activeHoldId: activeHoldId,
    reconfirmationState: reconfirmationState,
    terminalReason: terminal ? BookingTerminalReason.userCancelled : null,
    createdAtUtc: DateTime.utc(2026, 8, 9, 8),
    updatedAtUtc: DateTime.utc(2026, 8, 9, 9),
    confirmedAtUtc: state == BookingState.confirmed
        ? DateTime.utc(2026, 8, 9, 8, 1)
        : null,
    cancelledAtUtc: terminal ? DateTime.utc(2026, 8, 9, 9) : null,
  );
}

BookingHold _hold({required DateTime expiresAtUtc}) {
  return BookingHold(
    schemaVersion: 1,
    id: 'hold-1',
    bookingId: 'booking-1',
    userId: 'user-1',
    occurrenceId: 'occurrence-1',
    inventoryPoolId: 'pool-1',
    units: 1,
    kind: BookingHoldKind.waitlistOffer,
    state: BookingHoldState.active,
    createdAtUtc: DateTime.utc(2026, 8, 9, 8),
    expiresAtUtc: expiresAtUtc,
    revision: 0,
  );
}
