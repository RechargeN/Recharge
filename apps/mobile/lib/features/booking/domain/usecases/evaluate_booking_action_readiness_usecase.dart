import '../entities/booking.dart';
import '../entities/booking_action.dart';
import '../entities/booking_hold.dart';

class EvaluateBookingActionReadinessUseCase {
  const EvaluateBookingActionReadinessUseCase();

  BookingActionReadiness call({
    required Booking booking,
    required BookingAction action,
    required DateTime nowUtc,
    BookingHold? hold,
  }) {
    if (booking.isTerminal) {
      return const BookingActionReadiness(
        state: BookingActionReadinessState.blocked,
        reason: BookingActionReadinessReason.bookingTerminal,
      );
    }

    switch (action) {
      case BookingAction.cancel:
        return BookingActionReadiness.requiresServerCheck;
      case BookingAction.reconfirm:
        if (booking.state != BookingState.confirmed) {
          return _blocked(BookingActionReadinessReason.bookingStateMismatch);
        }
        if (booking.reconfirmationState !=
            BookingReconfirmationState.required) {
          return _blocked(
            BookingActionReadinessReason.reconfirmationNotRequired,
          );
        }
        return BookingActionReadiness.requiresServerCheck;
      case BookingAction.acceptWaitlistHold:
      case BookingAction.declineWaitlistHold:
        if (booking.state != BookingState.waitlisted ||
            booking.activeHoldId == null ||
            hold == null) {
          return _blocked(BookingActionReadinessReason.activeHoldRequired);
        }
        if (hold.id != booking.activeHoldId ||
            hold.bookingId != booking.id ||
            !hold.isActive) {
          return _blocked(BookingActionReadinessReason.holdMismatch);
        }
        if (!nowUtc.isBefore(hold.expiresAtUtc)) {
          return _blocked(BookingActionReadinessReason.holdExpiredLocally);
        }
        return BookingActionReadiness.requiresServerCheck;
      case BookingAction.approveApplication:
      case BookingAction.rejectApplication:
        if (booking.state != BookingState.pending ||
            booking.admissionMode != BookingAdmissionMode.application) {
          return _blocked(BookingActionReadinessReason.bookingStateMismatch);
        }
        return BookingActionReadiness.requiresServerCheck;
      case BookingAction.leaveWaitlist:
        if (booking.state != BookingState.waitlisted) {
          return _blocked(BookingActionReadinessReason.bookingStateMismatch);
        }
        return BookingActionReadiness.requiresServerCheck;
    }
  }

  static BookingActionReadiness _blocked(BookingActionReadinessReason reason) {
    return BookingActionReadiness(
      state: BookingActionReadinessState.blocked,
      reason: reason,
    );
  }
}
