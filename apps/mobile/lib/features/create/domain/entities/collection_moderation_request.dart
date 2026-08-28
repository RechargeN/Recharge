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
/// §6's requirement. [decidedByActorId] is the moderator's own trusted
/// actor id — never `bundle.publisherRef`, which identifies who the
/// *submission* is published as (a Professional Page, say), not who is
/// deciding on it.
class CollectionModerationDecision {
  const CollectionModerationDecision({
    required this.outcome,
    required this.decidedAtUtc,
    required this.decidedByActorId,
    this.rejectionReason,
  }) : assert(
         (outcome == CollectionModerationDecisionOutcome.rejected) ==
             (rejectionReason != null),
         'A rejection must carry a reason code; an acceptance must not.',
       );

  final CollectionModerationDecisionOutcome outcome;
  final DateTime decidedAtUtc;
  final String decidedByActorId;
  final CollectionModerationRejectionReason? rejectionReason;
}

/// A Collection version submitted without `publish.collection.direct`
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §6/§7 Шаг 5, §12). The bundle
/// already exists and has a permanent id — it just is not the active
/// Discover-facing version until a `moderate.collection` actor accepts it.
///
/// No dedicated moderation page ships in this slice — the commands over
/// this entity (`CreateController.loadPendingCollectionModerationRequests`/
/// `decideCollectionModerationRequest`) are real and unit/widget-tested,
/// but nothing in the presentation layer calls them, so the flow is not
/// reachable end to end through the running app yet.
class CollectionModerationRequest {
  const CollectionModerationRequest({
    required this.requestId,
    required this.bundle,
    required this.submittedAtUtc,
    required this.submittedByActorId,
    this.decision,
  });

  final String requestId;
  final CollectionPublishBundle bundle;
  final DateTime submittedAtUtc;

  /// The trusted actor (`CreateController._state.userId`, threaded through
  /// `submitForReview`'s own `actorId` param) who submitted this version —
  /// distinct from [submittedAsPublisher], which is who it is *published
  /// as* and may be a Professional Page a human actor merely represents.
  final String submittedByActorId;

  /// `null` while awaiting a `moderate.collection` decision; set exactly
  /// once and never after (§6 "sealed request").
  final CollectionModerationDecision? decision;

  String get collectionId => bundle.collectionId;

  /// Who this submission is published as — a `PublisherRef` (user or
  /// Professional Page), not the human actor who clicked submit. See
  /// [submittedByActorId] for that.
  PublisherRef get submittedAsPublisher => bundle.publisherRef;

  bool get isPending => decision == null;

  CollectionModerationRequest copyWith({CollectionModerationDecision? decision}) {
    return CollectionModerationRequest(
      requestId: requestId,
      bundle: bundle,
      submittedAtUtc: submittedAtUtc,
      submittedByActorId: submittedByActorId,
      decision: decision ?? this.decision,
    );
  }
}
