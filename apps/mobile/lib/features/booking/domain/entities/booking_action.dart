enum BookingAction {
  cancel,
  reconfirm,
  acceptWaitlistHold,
  declineWaitlistHold,
  approveApplication,
  rejectApplication,
  leaveWaitlist,
}

enum BookingActionReadinessState { allowed, blocked, requiresServerCheck }

enum BookingActionReadinessReason {
  structurallyAllowed,
  authoritativeCheckRequired,
  bookingTerminal,
  bookingStateMismatch,
  reconfirmationNotRequired,
  activeHoldRequired,
  holdMismatch,
  holdExpiredLocally,
}

class BookingActionReadiness {
  const BookingActionReadiness({required this.state, required this.reason});

  static const BookingActionReadiness requiresServerCheck =
      BookingActionReadiness(
        state: BookingActionReadinessState.requiresServerCheck,
        reason: BookingActionReadinessReason.authoritativeCheckRequired,
      );

  final BookingActionReadinessState state;
  final BookingActionReadinessReason reason;
}
