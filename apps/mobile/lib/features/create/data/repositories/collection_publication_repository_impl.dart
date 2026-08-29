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
    CollectionPublishBundle bundle, {
    required String actorId,
  }) async {
    final CollectionPublishReceipt receipt = await datasource.publish(
      bundle,
      actorId: actorId,
    );
    return _withSyncedActiveVersion(receipt);
  }

  @override
  Future<CollectionPublishReceipt> submitForReview(
    CollectionPublishBundle bundle, {
    required String actorId,
  }) {
    // Pending, not active — nothing for the Discover sink to see yet.
    return datasource.submitForReview(bundle, actorId: actorId);
  }

  @override
  Future<List<CollectionModerationRequest>> pendingRequests() {
    return datasource.pendingRequests();
  }

  @override
  Future<CollectionModerationDecisionResult> decide({
    required String requestId,
    required bool accept,
    required String decidedByActorId,
    CollectionModerationRejectionReason? rejectionReason,
  }) async {
    final (CollectionModerationRequest decided, PublishedCollectionVersion? activated) =
        await datasource.decide(
          requestId: requestId,
          accept: accept,
          decidedByActorId: decidedByActorId,
          rejectionReason: rejectionReason,
        );
    if (activated == null) {
      // Reject, or nothing to sync — trivially "synced".
      return CollectionModerationDecisionResult(
        request: decided,
        discoverSynced: true,
      );
    }
    final bool synced = await _activateSinkWithRetry(activated);
    return CollectionModerationDecisionResult(
      request: decided,
      discoverSynced: synced,
    );
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
  Future<bool> archive(
    String collectionId, {
    required String actorId,
    String? requestId,
  }) async {
    // CLG-PST-02 review finding: `datasource.archive` returns `true` both
    // the first time a real version is archived *and* on every later retry
    // of an already-archived collection — that is deliberate. A retry must
    // still (re)attempt the sink call below; short-circuiting it here (as
    // the previous version of this method did whenever the local record
    // was already gone) is exactly what made a failed Discover-sync
    // permanently unretryable.
    final bool hasRecord = await datasource.archive(
      collectionId,
      actorId: actorId,
      requestId: requestId,
    );
    if (!hasRecord) return true; // never published — nothing to sync, ever.
    return _archiveSinkWithRetry(collectionId);
  }

  @override
  Future<PublishedCollectionVersion?> getActiveVersion(String collectionId) {
    return datasource.activeVersion(collectionId);
  }

  /// Shared by [publish] and [removeItemsOnly]: both leave a fresh active
  /// version behind (fresh even on an idempotent replay, since the sink
  /// call is a separate concern from the datasource's own idempotency), so
  /// both need the same "sync it, then report honestly" tail.
  Future<CollectionPublishReceipt> _withSyncedActiveVersion(
    CollectionPublishReceipt receipt,
  ) async {
    if (receipt.outcome == CollectionPublishOutcome.pendingReview) {
      return receipt; // nothing active yet — should not reach here in
      // practice (submitForReview never calls this), guarded anyway.
    }
    final PublishedCollectionVersion? active = await datasource.activeVersion(
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

  Future<bool> _archiveSinkWithRetry(String collectionId) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        await _sink.archive(collectionId);
        return true;
      } on Object {
        // retry once, then report the failure back to the caller.
      }
    }
    return false;
  }
}
