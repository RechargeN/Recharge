import 'package:api_contracts/api_contracts.dart';

import '../../../core/network/backend_contract.dart';
import '../../../core/network/backend_transport.dart';

typedef BookingClock = DateTime Function();

abstract interface class BookingCallablePort {
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  );
}

final class BookingCallableFailure implements Exception {
  const BookingCallableFailure({required this.code, required this.dispatched});

  final String code;
  final bool dispatched;
}

enum BookingOperationState { pending, unknownOutcome, succeeded }

final class BookingOperationRecord {
  const BookingOperationRecord({
    required this.idempotencyKey,
    required this.firstAttemptAtUtc,
    required this.state,
  });

  final String idempotencyKey;
  final DateTime firstAttemptAtUtc;
  final BookingOperationState state;
}

abstract interface class BookingOperationStore {
  BookingOperationRecord? read(String idempotencyKey);
  void write(BookingOperationRecord record);
}

final class InMemoryBookingOperationStore implements BookingOperationStore {
  final Map<String, BookingOperationRecord> _records = {};

  @override
  BookingOperationRecord? read(String idempotencyKey) =>
      _records[idempotencyKey];

  @override
  void write(BookingOperationRecord record) {
    _records[record.idempotencyKey] = record;
  }
}

final class BookingCallableAdapter {
  BookingCallableAdapter({
    required BookingCallablePort port,
    required BookingOperationStore operations,
    BookingClock? clock,
  }) : _port = port,
       _operations = operations,
       _clock = clock ?? (() => DateTime.now().toUtc());

  static const Duration automaticRetryWindow = Duration(days: 7);

  final BookingCallablePort _port;
  final BookingOperationStore _operations;
  final BookingClock _clock;

  Future<BackendResult<BookingResultDto>> execute(
    String callableName,
    BookingCommandDto command, {
    required BackendCancellationToken cancellationToken,
  }) async {
    if (cancellationToken.isCancelled) return BackendCancelled();
    final now = _clock().toUtc();
    final existing = _operations.read(command.idempotencyKey);
    final firstAttempt = existing?.firstAttemptAtUtc ?? now;
    if (now.difference(firstAttempt) > automaticRetryWindow) {
      return BackendUnknownOutcome(reconciliationKey: command.idempotencyKey);
    }
    _operations.write(
      BookingOperationRecord(
        idempotencyKey: command.idempotencyKey,
        firstAttemptAtUtc: firstAttempt,
        state: existing?.state ?? BookingOperationState.pending,
      ),
    );
    try {
      final raw = await _port.invoke(callableName, command.toJson());
      if (cancellationToken.isCancelled) return BackendCancelled();
      final dto = BookingResultDto.fromJsonFailClosed(raw);
      final mapped = _map(dto);
      if (mapped is BackendSuccess<BookingResultDto>) {
        _operations.write(
          BookingOperationRecord(
            idempotencyKey: command.idempotencyKey,
            firstAttemptAtUtc: firstAttempt,
            state: BookingOperationState.succeeded,
          ),
        );
      }
      return mapped;
    } on BookingCallableFailure catch (error) {
      if (error.dispatched &&
          (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
        _operations.write(
          BookingOperationRecord(
            idempotencyKey: command.idempotencyKey,
            firstAttemptAtUtc: firstAttempt,
            state: BookingOperationState.unknownOutcome,
          ),
        );
        return BackendUnknownOutcome(reconciliationKey: command.idempotencyKey);
      }
      return BackendRejected(
        BackendFailure(code: BackendFailureCode.unavailable, retryable: true),
      );
    } on FormatException {
      return BackendRejected(
        const BackendFailure(
          code: BackendFailureCode.malformedResponse,
          retryable: false,
        ),
      );
    }
  }

  Future<BackendResult<BookingResultDto>> reconcile(
    String callableName,
    Map<String, Object?> query,
    String reconciliationKey,
  ) async {
    try {
      final dto = BookingResultDto.fromJsonFailClosed(
        await _port.invoke(callableName, query),
      );
      return _map(dto);
    } on Object {
      return BackendUnknownOutcome(reconciliationKey: reconciliationKey);
    }
  }

  BackendResult<BookingResultDto> _map(BookingResultDto dto) {
    switch (dto.kind) {
      case BookingResultKind.succeeded:
        return BackendSuccess(
          value: dto,
          serverRevision: dto.booking?.revision ?? 0,
          committedAtUtc: dto.serverTime,
        );
      case BookingResultKind.unsupportedContract:
        return BackendRejected(
          const BackendFailure(
            code: BackendFailureCode.unsupportedContract,
            retryable: false,
          ),
        );
      case BookingResultKind.rejected:
      case BookingResultKind.retryableFailure:
        final error = dto.error;
        if (error == null) {
          return BackendRejected(
            const BackendFailure(
              code: BackendFailureCode.malformedResponse,
              retryable: false,
            ),
          );
        }
        return BackendRejected(
          BackendFailure(
            code: _mapError(error.code),
            retryable: error.retryable,
            retryAfter: _retryAfter(error.details['retryAfterSeconds']),
          ),
        );
    }
  }
}

BackendFailureCode _mapError(BookingErrorCode code) {
  switch (code) {
    case BookingErrorCode.notAuthenticated:
      return BackendFailureCode.unauthenticated;
    case BookingErrorCode.notAuthorized:
    case BookingErrorCode.forbidden:
      return BackendFailureCode.permissionDenied;
    case BookingErrorCode.idempotencyConflict:
      return BackendFailureCode.idempotencyConflict;
    case BookingErrorCode.revisionConflict:
      return BackendFailureCode.staleRevision;
    case BookingErrorCode.unsupportedSchema:
      return BackendFailureCode.unsupportedContract;
    case BookingErrorCode.contention:
    case BookingErrorCode.temporarilyUnavailable:
      return BackendFailureCode.unavailable;
    default:
      return BackendFailureCode.invalidArgument;
  }
}

Duration? _retryAfter(Object? raw) =>
    raw is num && raw >= 0 ? Duration(seconds: raw.toInt()) : null;

enum BookingBackendBinding { localMock, devEmulator, productionDisabled }

final class BookingBackendEndpoint {
  BookingBackendEndpoint.devEmulator(Uri emulatorUri)
    : binding = BookingBackendBinding.devEmulator,
      uri = emulatorUri {
    if (emulatorUri.scheme != 'http' ||
        (emulatorUri.host != '127.0.0.1' && emulatorUri.host != 'localhost')) {
      throw ArgumentError.value(
        emulatorUri,
        'uri',
        'dev Booking endpoint must be a local Emulator',
      );
    }
  }

  const BookingBackendEndpoint.productionDisabled()
    : binding = BookingBackendBinding.productionDisabled,
      uri = null;

  final BookingBackendBinding binding;
  final Uri? uri;

  bool get enabled => binding == BookingBackendBinding.devEmulator;
}
