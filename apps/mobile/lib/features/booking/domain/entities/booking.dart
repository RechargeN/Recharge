enum BookingAdmissionMode { rsvp, booking, application }

enum BookingConfirmationMode { instant, manualApproval }

enum BookingState { pending, confirmed, cancelled, expired, waitlisted }

enum BookingChannel { onsite, online, any }

enum BookingReconfirmationState {
  notRequired,
  notOpen,
  required,
  confirmed,
  missed,
}

enum BookingTerminalReason {
  userCancelled,
  organizerCancelled,
  applicationRejected,
  occurrenceCancelled,
  eventCancelled,
  missedReconfirmation,
  waitlistOfferDeclined,
  waitlistOfferExpired,
  duplicateResolved,
  policyInvalidated,
}

class Booking {
  const Booking({
    required this.schemaVersion,
    required this.id,
    required this.revision,
    required this.userId,
    required this.eventId,
    required this.occurrenceId,
    required this.admissionMode,
    required this.confirmationMode,
    required this.state,
    required this.participantUnits,
    required this.namedGuestCount,
    required this.reconfirmationState,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.inventoryPoolId,
    this.channel,
    this.auxiliaryTrackId,
    this.eligibilitySnapshotRef,
    this.activeHoldId,
    this.terminalReason,
    this.confirmedAtUtc,
    this.cancelledAtUtc,
    this.expiredAtUtc,
  });

  final int schemaVersion;
  final String id;
  final int revision;
  final String userId;
  final String eventId;
  final String occurrenceId;
  final String? inventoryPoolId;
  final BookingChannel? channel;
  final String? auxiliaryTrackId;
  final BookingAdmissionMode admissionMode;
  final BookingConfirmationMode confirmationMode;
  final BookingState state;
  final int participantUnits;
  final int namedGuestCount;
  final String? eligibilitySnapshotRef;
  final String? activeHoldId;
  final BookingReconfirmationState reconfirmationState;
  final BookingTerminalReason? terminalReason;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? confirmedAtUtc;
  final DateTime? cancelledAtUtc;
  final DateTime? expiredAtUtc;

  bool get isTerminal =>
      state == BookingState.cancelled || state == BookingState.expired;

  bool get hasFiniteAllocation => inventoryPoolId != null;

  bool get isCapacityHolding =>
      state == BookingState.confirmed && hasFiniteAllocation;
}
