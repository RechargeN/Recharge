import '../entities/collection_moderation_request.dart';
import '../entities/collection_publication_data.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §12. Owns the atomic, idempotent
/// publish/removal-only writes for a Collection. The local/mock
/// implementation is a crash-recoverable staged store; a future backend
/// implements the same contract.
abstract interface class CollectionPublicationRepository {
  /// Throws [CollectionPublicationException] with
  /// [CollectionPublicationFailure.idempotencyConflict] if
  /// [CollectionPublishBundle.publishAttemptId] was already used with a
  /// different payload hash. Replaying the same key and hash returns the
  /// original receipt with
  /// [CollectionPublishOutcome.replayedIdempotentSuccess].
  Future<CollectionPublishReceipt> publish(CollectionPublishBundle bundle);

  /// §6/§7 Шаг 5: submitted without `publish.collection.direct` — a real,
  /// idempotent write happens (same idempotency contract as [publish]), but
  /// the resulting version is not activated until a `moderate.collection`
  /// actor calls [decide] with `accept: true`.
  Future<CollectionPublishReceipt> submitForReview(
    CollectionPublishBundle bundle,
  );

  /// Every version currently awaiting a `moderate.collection` decision —
  /// process-wide, not scoped to any one caller's draft.
  Future<List<CollectionModerationRequest>> pendingRequests();

  /// Accepts or rejects a pending version. Accepting activates it through
  /// the same Discover-sink path a direct [publish] uses; rejecting
  /// discards it without ever touching the active version.
  Future<void> decide({required String requestId, required bool accept});

  /// Throws [CollectionPublicationException] with
  /// [CollectionPublicationFailure.removalOnlyConflict] if the resolved
  /// active version differs from anything other than the removed refs, or
  /// [CollectionPublicationFailure.revisionConflict] if
  /// [CollectionRemovalOnlyCommand.expectedBaseRevisionOrHash] is stale.
  Future<CollectionPublishReceipt> removeItemsOnly(
    CollectionRemovalOnlyCommand command,
  );

  /// §3.11 lifecycle command — deactivates the Discover-facing version
  /// without publishing anything new. A no-op (but not an error) if
  /// [collectionId] has no active version.
  Future<void> archive(String collectionId);

  /// Create's own read of what it last wrote — distinct from Discover's
  /// independently-populated `PublishedCollectionDiscoveryPort` (§14).
  /// Used only to build a `CollectionRemovalOnlyCommand`'s base
  /// version/revision; Create does not otherwise read its own publication
  /// store as a general-purpose query surface.
  Future<PublishedCollectionVersion?> getActiveVersion(String collectionId);
}
