import 'collection_publication_data.dart';

/// A Collection version submitted without `publish.collection.direct`
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §6/§7 Шаг 5, §12). The bundle
/// already exists and has a permanent id — it just is not the active
/// Discover-facing version until a `moderate.collection` actor accepts it.
/// No dedicated moderation page ships in this slice, but the commands over
/// this entity are real: `CreateController.loadPendingCollectionModerationRequests`/
/// `decideCollectionModerationRequest` exercise the full accept/reject path.
class CollectionModerationRequest {
  const CollectionModerationRequest({
    required this.requestId,
    required this.bundle,
    required this.submittedAtUtc,
  });

  final String requestId;
  final CollectionPublishBundle bundle;
  final DateTime submittedAtUtc;

  String get collectionId => bundle.collectionId;
}
