import '../entities/collection_moderation_request.dart';
import '../entities/collection_publication_data.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §12. Owns the atomic, idempotent
/// publish/removal-only writes for a Collection. The local/mock
/// implementation is a crash-recoverable staged store; a future backend
/// implements the same contract.
abstract interface class CollectionPublicationRepository {
  /// [actorId] participates in the idempotency key alongside `commandType`
  /// (§12: effective key is `(actorId, commandType, requestId)`) — kept
  /// separate from [submitForReview]'s own key space so a replay of one
  /// command can never be read back as a receipt for the other.
  ///
  /// Throws [CollectionPublicationException] with
  /// [CollectionPublicationFailure.idempotencyConflict] if
  /// [CollectionPublishBundle.publishAttemptId] was already used by
  /// [actorId] with a different payload hash. Replaying the same key and
  /// hash returns the original receipt with
  /// [CollectionPublishOutcome.replayedIdempotentSuccess].
  Future<CollectionPublishReceipt> publish(
    CollectionPublishBundle bundle, {
    required String actorId,
  });

  /// §6/§7 Шаг 5: submitted without `publish.collection.direct` — a real,
  /// idempotent write happens (same idempotency contract as [publish], but
  /// its own key space — see [publish]'s doc), but the resulting version is
  /// not activated until a `moderate.collection` actor calls [decide] with
  /// `accept: true`.
  Future<CollectionPublishReceipt> submitForReview(
    CollectionPublishBundle bundle, {
    required String actorId,
  });

  /// Every version currently awaiting a `moderate.collection` decision —
  /// process-wide, not scoped to any one caller's draft.
  Future<List<CollectionModerationRequest>> pendingRequests();

  /// Accepts or rejects a pending version — a *sealed* decision (§6): once
  /// set, calling [decide] again on the same [requestId] throws
  /// [CollectionPublicationFailure.idempotencyConflict] rather than
  /// silently re-deciding. [rejectionReason] is required when `accept` is
  /// `false` and ignored (must be `null`) when it is `true`. Accepting
  /// activates the version through the same Discover-sink path a direct
  /// [publish] uses; rejecting discards it without ever touching the
  /// active version.
  Future<CollectionModerationDecisionResult> decide({
    required String requestId,
    required bool accept,
    CollectionModerationRejectionReason? rejectionReason,
  });

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
  /// [collectionId] has no active version. Returns whether Discover ended
  /// up in sync: `true` if there was nothing to archive or the sink
  /// deactivation succeeded, `false` if the local record is archived but a
  /// persistent Discover-sink failure means the public entry may still be
  /// visible or stale.
  Future<bool> archive(String collectionId);

  /// Create's own read of what it last wrote — distinct from Discover's
  /// independently-populated `PublishedCollectionDiscoveryPort` (§14).
  /// Used only to build a `CollectionRemovalOnlyCommand`'s base
  /// version/revision; Create does not otherwise read its own publication
  /// store as a general-purpose query surface.
  Future<PublishedCollectionVersion?> getActiveVersion(String collectionId);
}

/// [discoverSynced] is only meaningful when [decision]'s outcome is
/// `accepted` — a reject never touches the Discover sink, so it is always
/// `true` in that case (nothing needed syncing, not "succeeded at syncing").
class CollectionModerationDecisionResult {
  const CollectionModerationDecisionResult({
    required this.request,
    required this.discoverSynced,
  });

  final CollectionModerationRequest request;
  final bool discoverSynced;
}
