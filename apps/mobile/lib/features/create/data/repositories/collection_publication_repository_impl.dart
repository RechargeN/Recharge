import '../../domain/entities/collection_moderation_request.dart';
import '../../domain/entities/collection_publication_data.dart';
import '../../domain/repositories/collection_publication_index_sink.dart';
import '../../domain/repositories/collection_publication_repository.dart';
import '../datasources/collection_publication_local_datasource.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §14 review finding: Create's own
/// write must succeed unconditionally; the Discover-facing sink is a
/// separate, best-effort hop with its own retry, never a reason to fail (or
/// silently pretend to succeed on) a publish/removal/moderation-accept.
class CollectionPublicationRepositoryImpl
    implements CollectionPublicationRepository {
  const CollectionPublicationRepositoryImpl({
    required this.datasource,
    required CollectionPublicationIndexSink sink,
  }) : _sink = sink;

  final CollectionPublicationLocalDatasource datasource;
  final CollectionPublicationIndexSink _sink;

  @override
  Future<CollectionPublishReceipt> publish(
    CollectionPublishBundle bundle,
  ) async {
    final CollectionPublishReceipt receipt = await datasource.publish(bundle);
    return _withSyncedActiveVersion(receipt);
  }

  @override
  Future<CollectionPublishReceipt> submitForReview(
    CollectionPublishBundle bundle,
  ) {
    // Pending, not active — nothing for the Discover sink to see yet.
    return datasource.submitForReview(bundle);
  }

  @override
  Future<List<CollectionModerationRequest>> pendingRequests() {
    return datasource.pendingRequests();
  }

  @override
  Future<void> decide({
    required String requestId,
    required bool accept,
  }) async {
    final PublishedCollectionVersion? activated = await datasource.decide(
      requestId: requestId,
      accept: accept,
    );
    if (activated != null) {
      await _activateSinkWithRetry(activated);
    }
  }

  @override
  Future<CollectionPublishReceipt> removeItemsOnly(
    CollectionRemovalOnlyCommand command,
  ) async {
    final CollectionPublishReceipt receipt = await datasource.removeItemsOnly(
      command,
    );
    return _withSyncedActiveVersion(receipt);
  }

  @override
  Future<void> archive(String collectionId) async {
    final bool hadActive = await datasource.archive(collectionId);
    if (hadActive) {
      await _archiveSinkWithRetry(collectionId);
    }
  }

  @override
  Future<PublishedCollectionVersion?> getActiveVersion(String collectionId) {
    return Future<PublishedCollectionVersion?>.value(
      datasource.activeVersion(collectionId),
    );
  }

  /// Shared by [publish] and [removeItemsOnly]: both leave a fresh active
  /// version behind (fresh even on an idempotent replay, since the sink
  /// call is a separate concern from the datasource's own idempotency), so
  /// both need the same "sync it, then report honestly" tail.
  Future<CollectionPublishReceipt> _withSyncedActiveVersion(
    CollectionPublishReceipt receipt,
  ) async {
    final PublishedCollectionVersion? active = datasource.activeVersion(
      receipt.collectionId,
    );
    if (active == null) return receipt;
    final bool synced = await _activateSinkWithRetry(active);
    return synced ? receipt : receipt.copyWith(discoverSynced: false);
  }

  /// One immediate retry before giving up (DTL-OBJ-01 §3.5 review
  /// correction, applied here too) — the caller decides how a lasting
  /// failure is surfaced; this never throws.
  Future<bool> _activateSinkWithRetry(PublishedCollectionVersion version) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        await _sink.activate(version);
        return true;
      } on Object {
        // Second failure falls through — caller reports via
        // `discoverSynced`.
      }
    }
    return false;
  }

  /// `archive()` has no receipt channel back to the caller in this slice,
  /// so a lasting sink failure here is best-effort only: the local record
  /// is already archived (source of truth for Create), and a stale
  /// Discover-facing entry is a reconciliation concern out of scope for
  /// CLG-CRT-01.
  Future<void> _archiveSinkWithRetry(String collectionId) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        await _sink.archive(collectionId);
        return;
      } on Object {
        // retry once, then give up silently — see doc comment above.
      }
    }
  }
}
