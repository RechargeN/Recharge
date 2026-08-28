import 'collection_publication_data.dart';
import 'publisher_ref.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §6, table row "принять/отклонить
/// версию": a `moderate.collection` decision must be a *sealed* request —
/// immutable once decided, never silently re-decided — and a rejection must
/// always carry a typed reason code, never a free-form string.
enum CollectionModerationRejectionReason {
  policyViolation,
  qualityIssue,
  duplicateCollection,
  incompleteSubmission,
  other,
}

enum CollectionModerationDecisionOutcome { accepted, rejected }

/// Immutable once created — `decide()` builds exactly one of these per
/// request and never mutates it afterwards; that is the "sealed" half of
/// §6's requirement.
class CollectionModerationDecision {
  const CollectionModerationDecision({
    required this.outcome,
    required this.decidedAtUtc,
    this.rejectionReason,
  }) : assert(
         (outcome == CollectionModerationDecisionOutcome.rejected) ==
             (rejectionReason != null),
         'A rejection must carry a reason code; an acceptance must not.',
       );

  final CollectionModerationDecisionOutcome outcome;
  final DateTime decidedAtUtc;
  final CollectionModerationRejectionReason? rejectionReason;
}

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
    this.decision,
  });

  final String requestId;
  final CollectionPublishBundle bundle;
  final DateTime submittedAtUtc;

  /// `null` while awaiting a `moderate.collection` decision; set exactly
  /// once and never after (§6 "sealed request").
  final CollectionModerationDecision? decision;

  String get collectionId => bundle.collectionId;

  /// Who submitted this version — the request's "actor" (§6). Read off the
  /// bundle rather than duplicated onto this entity, since a
  /// `CollectionPublishBundle`'s `publisherRef` is already the trusted
  /// record of who it represents.
  PublisherRef get submittedBy => bundle.publisherRef;

  bool get isPending => decision == null;

  CollectionModerationRequest copyWith({CollectionModerationDecision? decision}) {
    return CollectionModerationRequest(
      requestId: requestId,
      bundle: bundle,
      submittedAtUtc: submittedAtUtc,
      decision: decision ?? this.decision,
    );
  }
}
