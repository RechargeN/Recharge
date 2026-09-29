import '../entities/collection_publication_data.dart';

/// Builds the removal-only self-service command (§3.11, §12, Вопрос 19).
/// This is the only place a "delete without moderation" request is
/// constructed — it can only narrow the active item set, never touch
/// anything else, and it refuses to empty the Collection outright
/// (that is what `archive.collection` is for).
class RemoveCollectionItemsOnlyUseCase {
  const RemoveCollectionItemsOnlyUseCase();

  CollectionRemovalOnlyCommand call({
    required PublishedCollectionVersion activeVersion,
    required Set<String> removedItemStableKeys,
    required String requestId,
    required String actorId,
  }) {
    if (removedItemStableKeys.isEmpty) {
      throw ArgumentError('At least one item must be selected for removal.');
    }
    final Set<String> activeKeys = activeVersion.bundle.items
        .map((item) => item.ref.stableKey)
        .toSet();
    if (!removedItemStableKeys.every(activeKeys.contains)) {
      throw ArgumentError(
        'Cannot remove an item that is not part of the active version.',
      );
    }
    if (removedItemStableKeys.length == activeKeys.length) {
      throw ArgumentError(
        'Removing every item would leave zero — archive the Collection '
        'instead (§3.11), removal-only cannot empty it.',
      );
    }
    return CollectionRemovalOnlyCommand(
      collectionId: activeVersion.collectionId,
      baseVersionId: activeVersion.collectionVersionId,
      // The active version id doubles as the revision pointer this command
      // is conditioned on — the reducer rejects it once a newer version is
      // active (§12).
      expectedBaseRevisionOrHash: activeVersion.collectionVersionId,
      removedItemRefs: removedItemStableKeys,
      requestId: requestId,
      actorId: actorId,
    );
  }
}
