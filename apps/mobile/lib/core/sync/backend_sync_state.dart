import '../network/backend_contract.dart';

enum BackendDataSourceKind { local, cache, server }

final class CacheProvenance {
  const CacheProvenance({
    required this.source,
    required this.schemaVersion,
    required this.serverRevision,
    required this.fetchedAtUtc,
    required this.expiresAtUtc,
  });

  final BackendDataSourceKind source;
  final int schemaVersion;
  final int? serverRevision;
  final DateTime fetchedAtUtc;
  final DateTime expiresAtUtc;

  bool isFreshAt(DateTime nowUtc) => !nowUtc.toUtc().isAfter(expiresAtUtc);
}

final class BackendSyncState<T> {
  const BackendSyncState({
    required this.status,
    this.value,
    this.provenance,
    this.failure,
    this.localRevision,
    this.serverRevision,
  });

  final BackendSyncStatus status;
  final T? value;
  final CacheProvenance? provenance;
  final BackendFailure? failure;
  final int? localRevision;
  final int? serverRevision;

  bool get isAuthoritative => status == BackendSyncStatus.serverConfirmed;
}
