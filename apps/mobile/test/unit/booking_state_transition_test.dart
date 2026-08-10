import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/domain/entities/booking.dart';
import 'package:recharge/features/booking/domain/entities/booking_hold.dart';
import 'package:recharge/features/booking/domain/usecases/validate_booking_state_transition_usecase.dart';

void main() {
  const validate = ValidateBookingStateTransitionUseCase();

  test('allowed Booking state matrix matches the Approved parent contract', () {
    const allowed = <BookingState, Set<BookingState>>{
      BookingState.pending: {
        BookingState.confirmed,
        BookingState.waitlisted,
        BookingState.cancelled,
      },
      BookingState.waitlisted: {
        BookingState.confirmed,
        BookingState.cancelled,
        BookingState.expired,
      },
      BookingState.confirmed: {BookingState.cancelled},
    };
    for (final entry in allowed.entries) {
      for (final target in entry.value) {
        final result = validate(
          before: _booking(entry.key, revision: 1),
          after: _booking(target, revision: 2),
        );
        expect(result.valid, isTrue, reason: '${entry.key} -> $target');
      }
    }
  });

  test('terminal state cannot reopen and revisions cannot regress', () {
    expect(
      validate(
        before: _booking(BookingState.cancelled, revision: 2),
        after: _booking(BookingState.confirmed, revision: 3),
      ).reason,
      BookingTransitionReason.terminalStateReopened,
    );
    expect(
      validate(
        before: _booking(BookingState.confirmed, revision: 2),
        after: _booking(BookingState.cancelled, revision: 1),
      ).reason,
      BookingTransitionReason.revisionRegression,
    );
  });

  test('same state is a projection update, not a fabricated transition', () {
    final result = validate(
      before: _booking(BookingState.confirmed, revision: 2),
      after: _booking(BookingState.confirmed, revision: 3),
    );
    expect(result.valid, isTrue);
    expect(result.reason, BookingTransitionReason.unchangedProjection);
  });

  test('hold transition is monotonic from active to terminal', () {
    expect(
      validate
          .validateHold(
            before: _hold(BookingHoldState.active, revision: 0),
            after: _hold(BookingHoldState.accepted, revision: 1),
          )
          .valid,
      isTrue,
    );
    expect(
      validate
          .validateHold(
            before: _hold(BookingHoldState.expired, revision: 1),
            after: _hold(BookingHoldState.active, revision: 2),
          )
          .valid,
      isFalse,
    );
  });
}

Booking _booking(BookingState state, {required int revision}) {
  final terminal =
      state == BookingState.cancelled || state == BookingState.expired;
  return Booking(
    schemaVersion: 1,
    id: 'booking-1',
    revision: revision,
    userId: 'user-1',
    eventId: 'event-1',
    occurrenceId: 'occurrence-1',
    inventoryPoolId: 'pool-1',
    channel: BookingChannel.onsite,
    admissionMode: state == BookingState.pending
        ? BookingAdmissionMode.application
        : BookingAdmissionMode.booking,
    confirmationMode: state == BookingState.pending
        ? BookingConfirmationMode.manualApproval
        : BookingConfirmationMode.instant,
    state: state,
    participantUnits: 1,
    namedGuestCount: 0,
    reconfirmationState: BookingReconfirmationState.notRequired,
    terminalReason: terminal ? BookingTerminalReason.userCancelled : null,
    createdAtUtc: DateTime.utc(2026, 8, 9, 8),
    updatedAtUtc: DateTime.utc(2026, 8, 9, 9),
    confirmedAtUtc: state == BookingState.confirmed
        ? DateTime.utc(2026, 8, 9, 8, 1)
        : null,
    cancelledAtUtc: state == BookingState.cancelled
        ? DateTime.utc(2026, 8, 9, 9)
        : null,
    expiredAtUtc: state == BookingState.expired
        ? DateTime.utc(2026, 8, 9, 9)
        : null,
  );
}

BookingHold _hold(BookingHoldState state, {required int revision}) {
  final terminal = state != BookingHoldState.active;
  return BookingHold(
    schemaVersion: 1,
    id: 'hold-1',
    bookingId: 'booking-1',
    userId: 'user-1',
    occurrenceId: 'occurrence-1',
    inventoryPoolId: 'pool-1',
    units: 1,
    kind: BookingHoldKind.waitlistOffer,
    state: state,
    createdAtUtc: DateTime.utc(2026, 8, 9, 8),
    expiresAtUtc: DateTime.utc(2026, 8, 9, 9),
    resolvedAtUtc: terminal ? DateTime.utc(2026, 8, 9, 9) : null,
    revision: revision,
  );
}
