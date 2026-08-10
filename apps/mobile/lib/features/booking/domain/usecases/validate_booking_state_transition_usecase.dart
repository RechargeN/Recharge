import '../entities/booking.dart';
import '../entities/booking_hold.dart';

enum BookingTransitionReason {
  allowed,
  unchangedProjection,
  aggregateMismatch,
  revisionRegression,
  terminalStateReopened,
  transitionForbidden,
}

class BookingTransitionValidation {
  const BookingTransitionValidation({
    required this.valid,
    required this.reason,
  });

  final bool valid;
  final BookingTransitionReason reason;
}

class ValidateBookingStateTransitionUseCase {
  const ValidateBookingStateTransitionUseCase();

  BookingTransitionValidation call({
    required Booking before,
    required Booking after,
  }) {
    if (before.id != after.id ||
        before.userId != after.userId ||
        before.eventId != after.eventId ||
        before.occurrenceId != after.occurrenceId) {
      return const BookingTransitionValidation(
        valid: false,
        reason: BookingTransitionReason.aggregateMismatch,
      );
    }
    if (after.revision < before.revision) {
      return const BookingTransitionValidation(
        valid: false,
        reason: BookingTransitionReason.revisionRegression,
      );
    }
    if (before.state == after.state) {
      return const BookingTransitionValidation(
        valid: true,
        reason: BookingTransitionReason.unchangedProjection,
      );
    }
    if (before.isTerminal) {
      return const BookingTransitionValidation(
        valid: false,
        reason: BookingTransitionReason.terminalStateReopened,
      );
    }
    final allowed = switch (before.state) {
      BookingState.pending => const {
        BookingState.confirmed,
        BookingState.waitlisted,
        BookingState.cancelled,
      },
      BookingState.waitlisted => const {
        BookingState.confirmed,
        BookingState.cancelled,
        BookingState.expired,
      },
      BookingState.confirmed => const {BookingState.cancelled},
      BookingState.cancelled || BookingState.expired => const <BookingState>{},
    };
    return BookingTransitionValidation(
      valid: allowed.contains(after.state),
      reason: allowed.contains(after.state)
          ? BookingTransitionReason.allowed
          : BookingTransitionReason.transitionForbidden,
    );
  }

  BookingTransitionValidation validateHold({
    required BookingHold before,
    required BookingHold after,
  }) {
    if (before.id != after.id || before.bookingId != after.bookingId) {
      return const BookingTransitionValidation(
        valid: false,
        reason: BookingTransitionReason.aggregateMismatch,
      );
    }
    if (after.revision < before.revision) {
      return const BookingTransitionValidation(
        valid: false,
        reason: BookingTransitionReason.revisionRegression,
      );
    }
    if (before.state == after.state) {
      return const BookingTransitionValidation(
        valid: true,
        reason: BookingTransitionReason.unchangedProjection,
      );
    }
    final valid = before.state == BookingHoldState.active && after.isTerminal;
    return BookingTransitionValidation(
      valid: valid,
      reason: valid
          ? BookingTransitionReason.allowed
          : BookingTransitionReason.terminalStateReopened,
    );
  }
}
