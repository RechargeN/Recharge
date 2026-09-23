import 'backend_contract.dart';
import 'backend_payload.dart';
import 'backend_request_context.dart';
import 'backend_result_mapper.dart';
import 'backend_transport.dart';

typedef AttemptIdFactory = String Function();
typedef BackendDelay = Future<void> Function(Duration duration);

final class BackendRetryPolicy {
  const BackendRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 2),
  }) : assert(maxAttempts > 0);

  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;

  Duration delayForAttempt(int attempt) {
    final int multiplier = 1 << (attempt - 1).clamp(0, 20);
    final int milliseconds = initialDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: milliseconds.clamp(0, maxDelay.inMilliseconds),
    );
  }
}

final class BackendReceipt {
  const BackendReceipt({
    required this.operation,
    required this.semanticHash,
    required this.response,
  });

  final String operation;
  final String semanticHash;
  final BackendResponse response;
}

abstract interface class BackendReceiptStore {
  BackendReceipt? read(String idempotencyKey);
  void write(String idempotencyKey, BackendReceipt receipt);
}

final class InMemoryBackendReceiptStore implements BackendReceiptStore {
  final Map<String, BackendReceipt> _values = <String, BackendReceipt>{};

  @override
  BackendReceipt? read(String idempotencyKey) => _values[idempotencyKey];

  @override
  void write(String idempotencyKey, BackendReceipt receipt) {
    _values[idempotencyKey] = receipt;
  }
}

final class BackendCommandClient {
  BackendCommandClient({
    required BackendTransport transport,
    required BackendReceiptStore receiptStore,
    required AttemptIdFactory attemptIdFactory,
    BackendResultMapper mapper = const BackendResultMapper(),
    BackendRetryPolicy retryPolicy = const BackendRetryPolicy(),
    BackendDelay? delay,
  }) : _transport = transport,
       _receiptStore = receiptStore,
       _attemptIdFactory = attemptIdFactory,
       _mapper = mapper,
       _retryPolicy = retryPolicy,
       _delay = delay ?? Future<void>.delayed;

  final BackendTransport _transport;
  final BackendReceiptStore _receiptStore;
  final AttemptIdFactory _attemptIdFactory;
  final BackendResultMapper _mapper;
  final BackendRetryPolicy _retryPolicy;
  final BackendDelay _delay;

  Future<BackendResult<T>> execute<T>({
    required String operation,
    required Map<String, Object?> payload,
    required BackendRequestContext context,
    required BackendDecoder<T> decode,
    required BackendCancellationToken cancellationToken,
    int? expectedRevision,
  }) async {
    final String calculatedHash;
    try {
      calculatedHash = semanticPayloadHash(payload);
    } on ArgumentError {
      return BackendRejected<T>(
        const BackendFailure(
          code: BackendFailureCode.invalidArgument,
          retryable: false,
        ),
      );
    }
    if (calculatedHash != context.semanticPayloadHash) {
      return BackendRejected<T>(
        const BackendFailure(
          code: BackendFailureCode.idempotencyConflict,
          retryable: false,
        ),
      );
    }
    final BackendReceipt? prior = _receiptStore.read(context.idempotencyKey);
    if (prior != null) {
      if (prior.operation != operation ||
          prior.semanticHash != context.semanticPayloadHash) {
        return BackendRejected<T>(
          BackendFailure(
            code: BackendFailureCode.idempotencyConflict,
            retryable: false,
          ),
        );
      }
      return _mapper.map<T>(prior.response, decode: decode);
    }

    BackendRequestContext attemptContext = context;
    for (int attempt = 1; attempt <= _retryPolicy.maxAttempts; attempt++) {
      if (cancellationToken.isCancelled) return BackendCancelled<T>();
      try {
        final BackendResponse response = await _transport.send(
          BackendRequest(
            operation: operation,
            kind: BackendOperationKind.command,
            context: attemptContext,
            payload: payload,
            expectedRevision: expectedRevision,
          ),
          cancellationToken: cancellationToken,
        );
        final BackendResult<T> result = _mapper.map<T>(
          response,
          decode: decode,
        );
        if (result is BackendSuccess<T>) {
          _receiptStore.write(
            context.idempotencyKey,
            BackendReceipt(
              operation: operation,
              semanticHash: context.semanticPayloadHash,
              response: response,
            ),
          );
          return result;
        }
        if (result is! BackendRejected<T> ||
            !result.failure.retryable ||
            attempt == _retryPolicy.maxAttempts) {
          return result;
        }
        await _delay(
          result.failure.retryAfter ?? _retryPolicy.delayForAttempt(attempt),
        );
        if (cancellationToken.isCancelled) return BackendCancelled<T>();
        attemptContext = attemptContext.nextAttempt(
          attemptRequestId: _attemptIdFactory(),
          createdAtUtc: DateTime.now().toUtc(),
        );
      } on BackendTransportException catch (error) {
        if (error.possiblySent) {
          return BackendUnknownOutcome<T>(
            reconciliationKey: context.idempotencyKey,
          );
        }
        if (!error.retryable || attempt == _retryPolicy.maxAttempts) {
          return BackendRejected<T>(
            BackendFailure(
              code: BackendFailureCode.unavailable,
              retryable: true,
            ),
          );
        }
        await _delay(_retryPolicy.delayForAttempt(attempt));
        attemptContext = attemptContext.nextAttempt(
          attemptRequestId: _attemptIdFactory(),
          createdAtUtc: DateTime.now().toUtc(),
        );
      }
    }
    return BackendRejected<T>(
      BackendFailure(code: BackendFailureCode.unavailable, retryable: true),
    );
  }
}

final class BackendQueryClient {
  const BackendQueryClient({
    required BackendTransport transport,
    BackendResultMapper mapper = const BackendResultMapper(),
  }) : _transport = transport,
       _mapper = mapper;

  final BackendTransport _transport;
  final BackendResultMapper _mapper;

  Future<BackendResult<T>> execute<T>({
    required String operation,
    required Map<String, Object?> payload,
    required BackendRequestContext context,
    required BackendDecoder<T> decode,
    required BackendCancellationToken cancellationToken,
  }) async {
    if (cancellationToken.isCancelled) return BackendCancelled<T>();
    try {
      final BackendResponse response = await _transport.send(
        BackendRequest(
          operation: operation,
          kind: BackendOperationKind.query,
          context: context,
          payload: payload,
        ),
        cancellationToken: cancellationToken,
      );
      if (cancellationToken.isCancelled) return BackendCancelled<T>();
      return _mapper.map<T>(response, decode: decode);
    } on BackendTransportException {
      return BackendRejected<T>(
        BackendFailure(code: BackendFailureCode.unavailable, retryable: true),
      );
    }
  }
}
