import 'backend_transport.dart';

typedef LocalBackendHandler =
    Future<BackendResponse> Function(BackendRequest request);

/// Credential-free backend datasource for local tests only.
///
/// It has no HTTP/Firebase dependency and cannot be selected implicitly.
final class LocalTestBackendDataSource implements BackendTransport {
  LocalTestBackendDataSource({
    required Map<String, LocalBackendHandler> handlers,
  }) : _handlers = Map<String, LocalBackendHandler>.unmodifiable(handlers);

  final Map<String, LocalBackendHandler> _handlers;

  @override
  Future<BackendResponse> send(
    BackendRequest request, {
    required BackendCancellationToken cancellationToken,
  }) async {
    if (cancellationToken.isCancelled) {
      throw const BackendTransportException(
        possiblySent: false,
        retryable: false,
      );
    }
    final LocalBackendHandler? handler = _handlers[request.operation];
    if (handler == null) {
      return BackendResponse(
        statusCode: 503,
        body: <String, Object?>{
          'status': 'failure',
          'errorCode': 'unavailable',
        },
      );
    }
    return handler(request);
  }
}
