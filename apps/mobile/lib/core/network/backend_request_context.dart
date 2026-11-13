final class BackendRequestContext {
  BackendRequestContext({
    required this.attemptRequestId,
    required this.idempotencyKey,
    required this.semanticPayloadHash,
    required this.clientBuild,
    required this.contractVersion,
    required DateTime createdAtUtc,
  }) : createdAtUtc = createdAtUtc.toUtc() {
    if (attemptRequestId.trim().isEmpty ||
        idempotencyKey.trim().isEmpty ||
        semanticPayloadHash.trim().isEmpty ||
        clientBuild.trim().isEmpty ||
        contractVersion.trim().isEmpty) {
      throw ArgumentError('Backend request context fields must be non-empty');
    }
  }

  final String attemptRequestId;
  final String idempotencyKey;
  final String semanticPayloadHash;
  final String clientBuild;
  final String contractVersion;
  final DateTime createdAtUtc;

  BackendRequestContext nextAttempt({
    required String attemptRequestId,
    required DateTime createdAtUtc,
  }) => BackendRequestContext(
    attemptRequestId: attemptRequestId,
    idempotencyKey: idempotencyKey,
    semanticPayloadHash: semanticPayloadHash,
    clientBuild: clientBuild,
    contractVersion: contractVersion,
    createdAtUtc: createdAtUtc,
  );
}
