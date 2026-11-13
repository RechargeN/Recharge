import '../../core/network/backend_contract.dart';
import '../../core/sync/backend_sync_state.dart';
import '../di/backend_binding_manifest.dart';

abstract interface class LocalReadPort<T> {
  Future<T?> read();
}

abstract interface class CacheReadPort<T> {
  Future<BackendSyncState<T>?> readCache();
}

abstract interface class ServerReadPort<T> {
  Future<BackendResult<T>> readServer();
}

final class ReversibleBackendRepositoryAdapter<T> {
  const ReversibleBackendRepositoryAdapter({
    required this.capabilityId,
    required this.manifest,
    required this.local,
    required this.cache,
    required this.server,
  });

  final String capabilityId;
  final BackendBindingManifest manifest;
  final LocalReadPort<T> local;
  final CacheReadPort<T> cache;
  final ServerReadPort<T> server;

  Future<BackendSyncState<T>> read() async {
    final BackendBindingMode mode = manifest.modeFor(capabilityId);
    if (mode == BackendBindingMode.disabled) {
      return BackendSyncState<T>(status: BackendSyncStatus.unavailable);
    }
    if (mode == BackendBindingMode.localOnly) {
      return BackendSyncState<T>(
        status: BackendSyncStatus.localOnly,
        value: await local.read(),
      );
    }

    final BackendSyncState<T>? cached = await cache.readCache();
    final BackendResult<T> remote = await server.readServer();
    return switch (remote) {
      BackendSuccess<T>() => BackendSyncState<T>(
        status: BackendSyncStatus.serverConfirmed,
        value: remote.value,
        serverRevision: remote.serverRevision,
      ),
      BackendRejected<T>(
        failure: BackendFailure(code: BackendFailureCode.unsupportedContract),
      ) =>
        BackendSyncState<T>(
          status: BackendSyncStatus.unsupported,
          value: cached?.value,
          provenance: cached?.provenance,
          failure: remote.failure,
        ),
      BackendRejected<T>() when cached?.value != null => BackendSyncState<T>(
        status: BackendSyncStatus.stale,
        value: cached!.value,
        provenance: cached.provenance,
        failure: remote.failure,
      ),
      BackendRejected<T>() => BackendSyncState<T>(
        status: BackendSyncStatus.unavailable,
        failure: remote.failure,
      ),
      BackendUnknownOutcome<T>() => BackendSyncState<T>(
        status: BackendSyncStatus.unknownOutcome,
        value: cached?.value,
        provenance: cached?.provenance,
      ),
      BackendCancelled<T>() => BackendSyncState<T>(
        status: cached?.value == null
            ? BackendSyncStatus.unavailable
            : BackendSyncStatus.cached,
        value: cached?.value,
        provenance: cached?.provenance,
      ),
    };
  }
}
