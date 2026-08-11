enum BookingFailureCode {
  notAuthenticated,
  notAuthorized,
  featureDisabled,
  eventUnavailable,
  occurrenceCancelled,
  registrationNotOpen,
  registrationClosed,
  eligibilityNotSatisfied,
  invalidGuestCount,
  poolRequired,
  poolUnavailable,
  soldOut,
  alreadyActive,
  concurrencyCapReached,
  revisionConflict,
  holdExpired,
  cancellationDeadlinePassed,
  idempotencyConflict,
  contention,
  forbidden,
  unsupportedContract,
  temporarilyUnavailable,
  invalidProjection,
}

class BookingFailure {
  const BookingFailure({
    required this.code,
    required this.retryable,
    required this.correlationId,
    this.field,
    this.retryAfterSeconds,
  });

  final BookingFailureCode code;
  final bool retryable;
  final String correlationId;
  final String? field;
  final int? retryAfterSeconds;
}
