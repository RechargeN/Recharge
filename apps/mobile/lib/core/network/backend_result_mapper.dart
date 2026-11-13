import 'backend_contract.dart';
import 'backend_transport.dart';

typedef BackendDecoder<T> = T Function(Map<String, Object?> value);

final class BackendResultMapper {
  const BackendResultMapper();

  BackendResult<T> map<T>(
    BackendResponse response, {
    required BackendDecoder<T> decode,
  }) {
    final Object? status = response.body['status'];
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        status == 'success') {
      final Object? rawValue = response.body['value'];
      final Object? revision = response.body['serverRevision'];
      final Object? committedAt = response.body['committedAtUtc'];
      if (rawValue is! Map || revision is! int || committedAt is! String) {
        return BackendRejected<T>(
          BackendFailure(
            code: BackendFailureCode.malformedResponse,
            retryable: false,
          ),
        );
      }
      try {
        return BackendSuccess<T>(
          value: decode(Map<String, Object?>.from(rawValue)),
          serverRevision: revision,
          committedAtUtc: DateTime.parse(committedAt).toUtc(),
        );
      } on Object {
        return BackendRejected<T>(
          BackendFailure(
            code: BackendFailureCode.malformedResponse,
            retryable: false,
          ),
        );
      }
    }
    return BackendRejected<T>(_failure(response));
  }

  BackendFailure _failure(BackendResponse response) {
    final String? rawCode = response.body['errorCode'] as String?;
    final BackendFailureCode code = switch (rawCode) {
      'unauthenticated' => BackendFailureCode.unauthenticated,
      'permission_denied' => BackendFailureCode.permissionDenied,
      'invalid_argument' => BackendFailureCode.invalidArgument,
      'idempotency_conflict' => BackendFailureCode.idempotencyConflict,
      'stale_revision' => BackendFailureCode.staleRevision,
      'rate_limited' => BackendFailureCode.rateLimited,
      'unsupported_contract' => BackendFailureCode.unsupportedContract,
      'unavailable' => BackendFailureCode.unavailable,
      _ => BackendFailureCode.malformedResponse,
    };
    return BackendFailure(
      code: code,
      retryable:
          code == BackendFailureCode.rateLimited ||
          code == BackendFailureCode.unavailable,
      retryAfter: switch (response.body['retryAfterMs']) {
        final int milliseconds when milliseconds > 0 => Duration(
          milliseconds: milliseconds,
        ),
        _ => null,
      },
    );
  }
}
