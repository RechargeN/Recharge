import 'backend_request_context.dart';
import 'backend_payload.dart';

enum BackendOperationKind { command, query }

final class BackendRequest {
  BackendRequest({
    required this.operation,
    required this.kind,
    required this.context,
    required Map<String, Object?> payload,
    this.expectedRevision,
  }) : payload = freezeBackendPayload(payload) {
    if (operation.trim().isEmpty) {
      throw ArgumentError.value(operation, 'operation', 'must be non-empty');
    }
    if (expectedRevision != null && expectedRevision! < 0) {
      throw ArgumentError.value(
        expectedRevision,
        'expectedRevision',
        'must be non-negative',
      );
    }
  }

  final String operation;
  final BackendOperationKind kind;
  final BackendRequestContext context;
  final Map<String, Object?> payload;
  final int? expectedRevision;
}

final class BackendResponse {
  BackendResponse({
    required this.statusCode,
    required Map<String, Object?> body,
  }) : body = freezeBackendPayload(body);

  final int statusCode;
  final Map<String, Object?> body;
}

abstract interface class BackendTransport {
  Future<BackendResponse> send(
    BackendRequest request, {
    required BackendCancellationToken cancellationToken,
  });
}

final class BackendCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

final class BackendTransportException implements Exception {
  const BackendTransportException({
    required this.possiblySent,
    required this.retryable,
  });

  final bool possiblySent;
  final bool retryable;
}
