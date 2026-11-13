enum BackendSyncStatus {
  localOnly,
  cached,
  synchronizing,
  serverConfirmed,
  stale,
  conflict,
  unknownOutcome,
  unsupported,
  unavailable,
}

enum BackendFailureCode {
  unauthenticated,
  permissionDenied,
  invalidArgument,
  idempotencyConflict,
  staleRevision,
  rateLimited,
  cancelled,
  unknownOutcome,
  unsupportedContract,
  unavailable,
  malformedResponse,
}

final class BackendFailure {
  const BackendFailure({
    required this.code,
    required this.retryable,
    this.retryAfter,
    this.reason,
  });

  final BackendFailureCode code;
  final bool retryable;
  final Duration? retryAfter;

  /// The server's own typed refusal code (for example `sold_out`), kept so the
  /// UI can explain a refusal that [code] only classifies.
  final String? reason;
}

sealed class BackendResult<T> {
  const BackendResult();
}

final class BackendSuccess<T> extends BackendResult<T> {
  const BackendSuccess({
    required this.value,
    required this.serverRevision,
    required this.committedAtUtc,
  });

  final T value;
  final int serverRevision;
  final DateTime committedAtUtc;
}

final class BackendRejected<T> extends BackendResult<T> {
  const BackendRejected(this.failure);

  final BackendFailure failure;
}

final class BackendCancelled<T> extends BackendResult<T> {
  const BackendCancelled();
}

final class BackendUnknownOutcome<T> extends BackendResult<T> {
  const BackendUnknownOutcome({required this.reconciliationKey});

  final String reconciliationKey;
}
