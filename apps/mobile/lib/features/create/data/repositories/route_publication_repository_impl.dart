import '../../domain/entities/route_publication_data.dart';
import '../../domain/repositories/route_publication_index_sink.dart';
import '../../domain/repositories/route_publication_repository.dart';
import '../datasources/route_publication_memory_datasource.dart';

class RoutePublicationRepositoryImpl implements RoutePublicationRepository {
  RoutePublicationRepositoryImpl(
    this._dataSource, {
    RoutePublicationIndexSink? indexSink,
  }) : _indexSink = indexSink;

  final RoutePublicationMemoryDataSource _dataSource;
  final RoutePublicationIndexSink? _indexSink;

  @override
  Future<RoutePublishReceipt> submitForReview({
    required String requestId,
    required RoutePublicationBundle bundle,
  }) async => _dataSource.submit(requestId: requestId, bundle: bundle);

  @override
  Future<RoutePublishReceipt> publishDirect(
    RoutePublicationBundle bundle,
  ) async {
    final receipt = _dataSource.publishDirect(bundle);
    await _syncPublishedReceipt(receipt);
    return receipt;
  }

  @override
  Future<RoutePublishReceipt> decide(RouteModerationDecision decision) async {
    final receipt = _dataSource.decide(decision);
    await _syncPublishedReceipt(receipt);
    return receipt;
  }

  @override
  Future<List<RouteModerationRequest>> pendingRequests() async =>
      _dataSource.pendingRequests();

  @override
  Future<RouteModerationRequest?> requestById(String requestId) async =>
      _dataSource.requestById(requestId);

  @override
  Future<RoutePublicationAggregate?> routeById(String routeId) async =>
      _dataSource.routeById(routeId);

  @override
  Future<RoutePublicationAggregate?> routeByVersionId(String versionId) async =>
      _dataSource.routeByVersionId(versionId);

  @override
  Future<RoutePublicationAggregate?> archive({
    required String routeId,
    required String actorId,
    required String attemptId,
    required DateTime archivedAtUtc,
  }) async {
    final aggregate = _dataSource.archive(
      routeId: routeId,
      actorId: actorId,
      attemptId: attemptId,
      archivedAtUtc: archivedAtUtc,
    );
    if (aggregate?.lifecycleStatus == RouteLifecycleStatus.archived) {
      await _indexSink?.archive(routeId);
    }
    return aggregate;
  }

  @override
  Future<RoutePublicationAggregate?> setLifecycle({
    required String routeId,
    required RouteLifecycleStatus status,
    required String actorId,
    required String attemptId,
    required String reasonCode,
    required DateTime changedAtUtc,
  }) async {
    final aggregate = _dataSource.setLifecycle(
      routeId: routeId,
      status: status,
      actorId: actorId,
      attemptId: attemptId,
      reasonCode: reasonCode,
      changedAtUtc: changedAtUtc,
    );
    final active = aggregate?.activeVersion;
    if (aggregate == null || active == null) return aggregate;
    if (status == RouteLifecycleStatus.active ||
        status == RouteLifecycleStatus.needsReview) {
      await _indexSink?.activate(active);
    } else {
      await _indexSink?.archive(routeId);
    }
    return aggregate;
  }

  Future<void> _syncPublishedReceipt(RoutePublishReceipt receipt) async {
    if (!receipt.isPublished) return;
    final active = _dataSource.routeById(receipt.routeId)?.activeVersion;
    if (active == null ||
        active.versionId != receipt.versionId ||
        active.geometryHash != receipt.geometryHash) {
      throw StateError('Published Route receipt/version mismatch.');
    }
    await _indexSink?.activate(active);
  }
}
