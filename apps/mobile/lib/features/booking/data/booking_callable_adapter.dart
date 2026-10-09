import 'package:api_contracts/api_contracts.dart';

import '../../../core/network/backend_clients.dart';
import '../../../core/network/backend_contract.dart';
import '../../../core/network/backend_payload.dart';
import '../../../core/network/backend_transport.dart';

typedef BookingClock = DateTime Function();

abstract interface class BookingCallablePort {
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  );
}

final class BookingCallableFailure implements Exception {
  const BookingCallableFailure({
    required this.code,
    required this.dispatched,
    this.retryAfter,
  });

  final String code;
  final bool dispatched;
  final Duration? retryAfter;
}

final class BookingReconciliationRequest {
  BookingReconciliationRequest({
    required this.callableName,
    required Map<String, Object?> query,
  }) : query = Map<String, Object?>.unmodifiable(query) {
    if (callableName != 'getMyBookingV1' ||
        query['queryType'] != 'getMyBooking') {
      throw ArgumentError(
        'Booking reconciliation must use the authoritative getMyBooking query',
      );
    }
    _rejectClientAuthority(query);
  }

  final String callableName;
  final Map<String, Object?> query;
}

enum BookingOperationState {
  pending,
  unknownOutcome,
  succeeded,
  failedFinal,
  cancelled,
  expiredUnknownAfter7d,
}

final class BookingOperationRecord {
  const BookingOperationRecord({
    required this.idempotencyKey,
    required this.firstAttemptAtUtc,
    required this.state,
    String? operationId,
    this.reconciliationAttempts = 0,
    this.lastReconciledAtUtc,
    this.reconciliationCallableName,
    this.reconciliationQuery,
  }) : operationId = operationId ?? idempotencyKey;

  final String idempotencyKey;

  /// V1 uses the stable idempotency identity as its logical operation id.
  final String operationId;
  final DateTime firstAttemptAtUtc;
  final BookingOperationState state;
  final int reconciliationAttempts;
  final DateTime? lastReconciledAtUtc;
  final String? reconciliationCallableName;
  final Map<String, Object?>? reconciliationQuery;

  bool get isTerminal => switch (state) {
    BookingOperationState.succeeded ||
    BookingOperationState.failedFinal ||
    BookingOperationState.cancelled ||
    BookingOperationState.expiredUnknownAfter7d => true,
    BookingOperationState.pending ||
    BookingOperationState.unknownOutcome => false,
  };
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
    BackendReceiptStore? receipts,
    BookingClock? clock,
  }) : _port = port,
       _operations = operations,
       _receipts = receipts,
       _clock = clock ?? (() => DateTime.now().toUtc());

  static const Duration automaticRetryWindow = Duration(days: 7);
  static const List<Duration> reconciliationSchedule = <Duration>[
    Duration.zero,
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
    Duration(hours: 6),
  ];

  final BookingCallablePort _port;
  final BookingOperationStore _operations;
  final BackendReceiptStore? _receipts;
  final BookingClock _clock;

  Future<BackendResult<BookingResultDto>> execute(
    String callableName,
    BookingCommandDto command, {
    required BackendCancellationToken cancellationToken,
    BookingReconciliationRequest? reconciliation,
  }) async {
    final semanticHash = _commandSemanticHash(command);
    final prior = _receipts?.read(command.idempotencyKey);
    if (prior != null) {
      if (prior.operation != callableName ||
          prior.semanticHash != semanticHash) {
        return BackendRejected(
          const BackendFailure(
            code: BackendFailureCode.idempotencyConflict,
            retryable: false,
          ),
        );
      }
      return _map(BookingResultDto.fromJsonFailClosed(prior.response.body));
    }
    if (cancellationToken.isCancelled) {
      _operations.write(
        BookingOperationRecord(
          idempotencyKey: command.idempotencyKey,
          firstAttemptAtUtc: _clock().toUtc(),
          state: BookingOperationState.cancelled,
          reconciliationCallableName: reconciliation?.callableName,
          reconciliationQuery: reconciliation?.query,
        ),
      );
      return BackendCancelled();
    }
    final now = _clock().toUtc();
    final existing = _operations.read(command.idempotencyKey);
    final firstAttempt = existing?.firstAttemptAtUtc ?? now;
    if (now.difference(firstAttempt) > automaticRetryWindow) {
      _operations.write(
        BookingOperationRecord(
          idempotencyKey: command.idempotencyKey,
          operationId: existing?.operationId,
          firstAttemptAtUtc: firstAttempt,
          state: BookingOperationState.expiredUnknownAfter7d,
          reconciliationAttempts: existing?.reconciliationAttempts ?? 0,
          lastReconciledAtUtc: existing?.lastReconciledAtUtc,
          reconciliationCallableName:
              existing?.reconciliationCallableName ??
              reconciliation?.callableName,
          reconciliationQuery:
              existing?.reconciliationQuery ?? reconciliation?.query,
        ),
      );
      return BackendUnknownOutcome(reconciliationKey: command.idempotencyKey);
    }
    if (existing?.isTerminal ?? false) {
      return BackendUnknownOutcome(reconciliationKey: existing!.operationId);
    }
    _operations.write(
      BookingOperationRecord(
        idempotencyKey: command.idempotencyKey,
        firstAttemptAtUtc: firstAttempt,
        state: existing?.state ?? BookingOperationState.pending,
        operationId: existing?.operationId,
        reconciliationAttempts: existing?.reconciliationAttempts ?? 0,
        lastReconciledAtUtc: existing?.lastReconciledAtUtc,
        reconciliationCallableName:
            existing?.reconciliationCallableName ??
            reconciliation?.callableName,
        reconciliationQuery:
            existing?.reconciliationQuery ?? reconciliation?.query,
      ),
    );
    try {
      final raw = await _port.invoke(callableName, command.toJson());
      if (cancellationToken.isCancelled) {
        _operations.write(
          BookingOperationRecord(
            idempotencyKey: command.idempotencyKey,
            operationId: existing?.operationId,
            firstAttemptAtUtc: firstAttempt,
            state: BookingOperationState.unknownOutcome,
            reconciliationAttempts: existing?.reconciliationAttempts ?? 0,
            lastReconciledAtUtc: existing?.lastReconciledAtUtc,
            reconciliationCallableName:
                existing?.reconciliationCallableName ??
                reconciliation?.callableName,
            reconciliationQuery:
                existing?.reconciliationQuery ?? reconciliation?.query,
          ),
        );
        return BackendUnknownOutcome(reconciliationKey: command.idempotencyKey);
      }
      final dto = BookingResultDto.fromJsonFailClosed(raw);
      final mapped = _map(dto);
      if (mapped is BackendSuccess<BookingResultDto>) {
        _receipts?.write(
          command.idempotencyKey,
          BackendReceipt(
            operation: callableName,
            semanticHash: semanticHash,
            response: BackendResponse(statusCode: 200, body: raw),
          ),
        );
        _operations.write(
          BookingOperationRecord(
            idempotencyKey: command.idempotencyKey,
            firstAttemptAtUtc: firstAttempt,
            state: BookingOperationState.succeeded,
            operationId: existing?.operationId,
            reconciliationAttempts: existing?.reconciliationAttempts ?? 0,
            lastReconciledAtUtc: existing?.lastReconciledAtUtc,
            reconciliationCallableName:
                existing?.reconciliationCallableName ??
                reconciliation?.callableName,
            reconciliationQuery:
                existing?.reconciliationQuery ?? reconciliation?.query,
          ),
        );
      } else if (mapped case BackendRejected<BookingResultDto>(
        failure: final failure,
      )) {
        _operations.write(
          BookingOperationRecord(
            idempotencyKey: command.idempotencyKey,
            operationId: existing?.operationId,
            firstAttemptAtUtc: firstAttempt,
            state: failure.retryable
                ? BookingOperationState.pending
                : BookingOperationState.failedFinal,
            reconciliationAttempts: existing?.reconciliationAttempts ?? 0,
            lastReconciledAtUtc: existing?.lastReconciledAtUtc,
            reconciliationCallableName:
                existing?.reconciliationCallableName ??
                reconciliation?.callableName,
            reconciliationQuery:
                existing?.reconciliationQuery ?? reconciliation?.query,
          ),
        );
      }
      return mapped;
    } on BookingCallableFailure catch (error) {
      if (error.dispatched &&
          _ambiguousPostDispatchCodes.contains(error.code)) {
        _operations.write(
          BookingOperationRecord(
            idempotencyKey: command.idempotencyKey,
            firstAttemptAtUtc: firstAttempt,
            state: BookingOperationState.unknownOutcome,
            operationId: existing?.operationId,
            reconciliationAttempts: existing?.reconciliationAttempts ?? 0,
            lastReconciledAtUtc: existing?.lastReconciledAtUtc,
            reconciliationCallableName:
                existing?.reconciliationCallableName ??
                reconciliation?.callableName,
            reconciliationQuery:
                existing?.reconciliationQuery ?? reconciliation?.query,
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
    final existing = _operations.read(reconciliationKey);
    final now = _clock().toUtc();
    if (existing != null &&
        now.difference(existing.firstAttemptAtUtc) > automaticRetryWindow) {
      _operations.write(
        BookingOperationRecord(
          idempotencyKey: existing.idempotencyKey,
          operationId: existing.operationId,
          firstAttemptAtUtc: existing.firstAttemptAtUtc,
          state: BookingOperationState.expiredUnknownAfter7d,
          reconciliationAttempts: existing.reconciliationAttempts,
          lastReconciledAtUtc: now,
          reconciliationCallableName: existing.reconciliationCallableName,
          reconciliationQuery: existing.reconciliationQuery,
        ),
      );
      return BackendUnknownOutcome(reconciliationKey: existing.operationId);
    }
    try {
      final raw = await _port.invoke(callableName, query);
      final mapped = _mapReconciliation(raw, reconciliationKey);
      if (existing != null) {
        final terminal =
            mapped is BackendSuccess<BookingResultDto> ||
            (mapped is BackendRejected<BookingResultDto> &&
                !mapped.failure.retryable);
        _operations.write(
          BookingOperationRecord(
            idempotencyKey: existing.idempotencyKey,
            operationId: existing.operationId,
            firstAttemptAtUtc: existing.firstAttemptAtUtc,
            state: terminal
                ? mapped is BackendSuccess<BookingResultDto>
                      ? BookingOperationState.succeeded
                      : BookingOperationState.failedFinal
                : BookingOperationState.unknownOutcome,
            reconciliationAttempts: existing.reconciliationAttempts + 1,
            lastReconciledAtUtc: now,
            reconciliationCallableName: existing.reconciliationCallableName,
            reconciliationQuery: existing.reconciliationQuery,
          ),
        );
      }
      return mapped;
    } on Object {
      return BackendUnknownOutcome(reconciliationKey: reconciliationKey);
    }
  }

  Future<BackendResult<BookingResultDto>> reconcileStored(
    String reconciliationKey,
  ) async {
    final existing = _operations.read(reconciliationKey);
    if (existing == null ||
        existing.reconciliationCallableName == null ||
        existing.reconciliationQuery == null) {
      return BackendUnknownOutcome(reconciliationKey: reconciliationKey);
    }
    return reconcile(
      existing.reconciliationCallableName!,
      existing.reconciliationQuery!,
      reconciliationKey,
    );
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
            reason: error.code.wireValue,
          ),
        );
    }
  }

  BackendResult<BookingResultDto> _mapReconciliation(
    Map<String, Object?> raw,
    String reconciliationKey,
  ) {
    final kind = raw['kind'];
    if (kind == 'notFound') {
      return BackendUnknownOutcome(reconciliationKey: reconciliationKey);
    }
    final normalized = <String, Object?>{
      'schemaVersion': raw['schemaVersion'],
      'kind': kind == 'found' ? 'succeeded' : kind,
      'requestId': raw['requestId'],
      'correlationId': raw['error'] is Map
          ? (raw['error']! as Map)['correlationId'] ?? raw['requestId']
          : raw['requestId'],
      'serverTime': raw['serverTime'],
      if (raw['booking'] != null) 'booking': raw['booking'],
      if (raw['error'] != null) 'error': raw['error'],
      if (raw['unsupportedPayload'] != null)
        'unsupportedPayload': raw['unsupportedPayload'],
    };
    return _map(BookingResultDto.fromJsonFailClosed(normalized));
  }
}

String _commandSemanticHash(BookingCommandDto command) =>
    semanticPayloadHash(<String, Object?>{
      'schemaVersion': command.schemaVersion,
      'commandType': command.commandType.name,
      if (command.expectedBookingRevision != null)
        'expectedBookingRevision': command.expectedBookingRevision,
      if (command.occurredAgainstEventRevision != null)
        'occurredAgainstEventRevision': command.occurredAgainstEventRevision,
      'payload': command.payload,
    });

BackendFailureCode _mapError(BookingErrorCode code) {
  switch (code) {
    case BookingErrorCode.notAuthenticated:
    case BookingErrorCode.sessionRevoked:
    case BookingErrorCode.sessionExpired:
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
    case BookingErrorCode.rateLimited:
    case BookingErrorCode.sessionRefreshRequired:
      return BackendFailureCode.unavailable;
    default:
      return BackendFailureCode.invalidArgument;
  }
}

Duration? _retryAfter(Object? raw) =>
    raw is num && raw >= 0 ? Duration(seconds: raw.toInt()) : null;

const Set<String> _ambiguousPostDispatchCodes = <String>{
  'unavailable',
  'deadline-exceeded',
  'internal',
  'unknown',
  'aborted',
  'cancelled',
};

void _rejectClientAuthority(Object? value) {
  const forbidden = <String>{
    'actorid',
    'userid',
    'publisherid',
    'pageid',
    'creatorid',
    'adminid',
    'capabilities',
    'roles',
    'accesssnapshot',
    'sessioncontext',
  };
  if (value is Map) {
    for (final entry in value.entries) {
      if (forbidden.contains(entry.key.toString().toLowerCase())) {
        throw ArgumentError('Client authority is forbidden in Booking query');
      }
      _rejectClientAuthority(entry.value);
    }
  } else if (value is List) {
    for (final item in value) {
      _rejectClientAuthority(item);
    }
  }
}

enum BookingBackendBinding { localMock, devEmulator, productionDisabled }

final class BookingBackendEndpoint {
  const BookingBackendEndpoint.localMock()
    : binding = BookingBackendBinding.localMock,
      uri = null;

  BookingBackendEndpoint.devEmulator(Uri emulatorUri)
    : binding = BookingBackendBinding.devEmulator,
      uri = emulatorUri {
    final path = emulatorUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (emulatorUri.scheme != 'http' ||
        (emulatorUri.host != '127.0.0.1' && emulatorUri.host != 'localhost') ||
        path.length != 2 ||
        path[0] != 'demo-recharge' ||
        path[1] != 'europe-west1') {
      throw ArgumentError.value(
        emulatorUri,
        'uri',
        'dev Booking endpoint must be the local demo-recharge/europe-west1 Emulator',
      );
    }
  }

  const BookingBackendEndpoint.productionDisabled()
    : binding = BookingBackendBinding.productionDisabled,
      uri = null;

  final BookingBackendBinding binding;
  final Uri? uri;

  bool get enabled => binding == BookingBackendBinding.devEmulator;

  Uri callableUri(String callableName) {
    if (!enabled || uri == null) {
      throw StateError('Booking Functions transport is disabled');
    }
    if (!_bookingCallableAllowlist.contains(callableName)) {
      throw ArgumentError.value(callableName, 'callableName');
    }
    final base = uri.toString().endsWith('/') ? uri! : Uri.parse('${uri!}/');
    return base.resolve(callableName);
  }
}

const Set<String> _bookingCallableAllowlist = <String>{
  'establishIdentitySessionV1',
  'refreshIdentitySessionV1',
  'recoverIdentitySessionsV1',
  'createInternalBookingV1',
  'cancelInternalBookingV1',
  // F2: reconfirmation after a material reschedule (same Session and journal).
  'reconfirmInternalBookingV1',
  'getMyBookingV1',
  'listMyBookingsV1',
  'getEventAvailabilityV1',
  // C1: default-off Emulator-only Media entry (same Session and token path).
  'mediaCommandV1',
  'mediaQueryV1',
  'uploadMediaBytesV1',
  // C3: default-off Emulator-only Event authoring through Content.
  'contentCommandV1',
  'contentQueryV1',
  // E2: default-off Emulator-only Discover read over the server Catalog.
  'discoverQueryV1',
  // F1: default-off Emulator-only Notifications inbox.
  'notificationsQueryV1',
  'notificationsCommandV1',
};
