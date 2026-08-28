import 'collection_draft_data.dart';
import 'collection_item_draft.dart';
import 'publisher_ref.dart';

/// Canonical, atomic publish payload
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §12). Built once by
/// `BuildCollectionPublicationBundleUseCase` from a validated,
/// composition-reviewed draft — never assembled ad hoc by callers.
class CollectionPublishBundle {
  const CollectionPublishBundle({
    required this.collectionId,
    required this.collectionVersionId,
    required this.publisherRef,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.coverMediaId,
    required this.marketCityId,
    required this.areaLabel,
    this.areaId,
    this.budgetTier,
    required this.visibility,
    required this.sections,
    required this.items,
    required this.compositionReview,
    required this.publishAttemptId,
  });

  final String collectionId;
  final String collectionVersionId;
  final PublisherRef publisherRef;

  final String title;
  final String shortDescription;
  final String fullDescription;
  final String? coverMediaId;
  final String marketCityId;
  final String areaLabel;
  final String? areaId;
  final CollectionBudgetTier? budgetTier;

  /// `public` / `unlisted` — see `VisibilityType` on `CreateDraftEntity`.
  final String visibility;

  final List<CollectionSectionDraft> sections;
  final List<CollectionItemDraft> items;
  final CollectionCompositionReview compositionReview;

  /// Idempotency key for `(actorId, commandType, requestId)` (§12) — the
  /// caller supplies a stable value per publish attempt so a retry replays
  /// the same receipt instead of creating a second Collection.
  final String publishAttemptId;

  /// Used by the removal-only reducer (§12) to derive the next active
  /// version — every field except `collectionVersionId`, `items` and
  /// `publishAttemptId` is carried over unchanged, by construction.
  CollectionPublishBundle copyWith({
    String? collectionVersionId,
    List<CollectionItemDraft>? items,
    String? publishAttemptId,
  }) {
    return CollectionPublishBundle(
      collectionId: collectionId,
      collectionVersionId: collectionVersionId ?? this.collectionVersionId,
      publisherRef: publisherRef,
      title: title,
      shortDescription: shortDescription,
      fullDescription: fullDescription,
      coverMediaId: coverMediaId,
      marketCityId: marketCityId,
      areaLabel: areaLabel,
      areaId: areaId,
      budgetTier: budgetTier,
      visibility: visibility,
      sections: sections,
      items: items ?? this.items,
      compositionReview: compositionReview,
      publishAttemptId: publishAttemptId ?? this.publishAttemptId,
    );
  }
}

enum CollectionPublishOutcome {
  created,
  replayedIdempotentSuccess,

  /// §6/§7 Шаг 5: submitted without `publish.collection.direct` — a real,
  /// idempotent write happened (a version now exists), but it is not the
  /// active Discover-facing version until `moderate.collection` accepts it.
  pendingReview,
}

/// Typed lifecycle, not a single ambiguous timestamp (review finding):
/// [publishedAtUtc] is set only when [outcome] is [created] or
/// [replayedIdempotentSuccess] — a version that actually became active.
/// [submittedAtUtc] is set only for [pendingReview] — a version exists but
/// was never activated. Exactly one of the two is non-null.
class CollectionPublishReceipt {
  const CollectionPublishReceipt({
    required this.collectionId,
    required this.collectionVersionId,
    required this.outcome,
    this.publishedAtUtc,
    this.submittedAtUtc,
    this.discoverSynced = true,
  }) : assert(
         (publishedAtUtc == null) != (submittedAtUtc == null),
         'Exactly one of publishedAtUtc/submittedAtUtc must be set.',
       );

  final String collectionId;
  final String collectionVersionId;
  final CollectionPublishOutcome outcome;
  final DateTime? publishedAtUtc;
  final DateTime? submittedAtUtc;

  /// False when the write to Create's own store succeeded but the
  /// Discover-facing sink failed after a retry (§14 review finding) — the
  /// caller must not report this as a failed publish, only track it
  /// separately. Always true for [pendingReview] (nothing to sync yet).
  final bool discoverSynced;

  CollectionPublishReceipt copyWith({
    CollectionPublishOutcome? outcome,
    bool? discoverSynced,
  }) {
    return CollectionPublishReceipt(
      collectionId: collectionId,
      collectionVersionId: collectionVersionId,
      outcome: outcome ?? this.outcome,
      publishedAtUtc: publishedAtUtc,
      submittedAtUtc: submittedAtUtc,
      discoverSynced: discoverSynced ?? this.discoverSynced,
    );
  }
}

/// The active, immutable version of a published Collection — what
/// `CollectionPublicationIndexSink.activate` receives, and what the
/// app-level `CollectionPublicationDiscoveryAdapter` reads to build the
/// Discover-owned `PublishedCollectionDiscoveryEntity` (§14). Create never
/// hands this type to Discover directly.
class PublishedCollectionVersion {
  const PublishedCollectionVersion({
    required this.bundle,
    required this.publishedAtUtc,
  });

  final CollectionPublishBundle bundle;
  final DateTime publishedAtUtc;

  String get collectionId => bundle.collectionId;
  String get collectionVersionId => bundle.collectionVersionId;
}

/// Removal-only self-service command (§3.11, §12, Вопрос 19). The reducer
/// that accepts this — not the caller — builds the resulting active
/// version; the command itself can only ever narrow the item set.
class CollectionRemovalOnlyCommand {
  const CollectionRemovalOnlyCommand({
    required this.collectionId,
    required this.baseVersionId,
    required this.expectedBaseRevisionOrHash,
    required this.removedItemRefs,
    required this.requestId,
  });

  final String collectionId;
  final String baseVersionId;
  final String expectedBaseRevisionOrHash;
  final Set<String> removedItemRefs; // CollectionObjectRef.stableKey values
  final String requestId;
}

enum CollectionPublicationFailure {
  idempotencyConflict,
  revisionConflict,
  notFound,
  removalOnlyConflict,
  persistenceUnavailable,
}

class CollectionPublicationException implements Exception {
  const CollectionPublicationException(this.failure, this.message);

  final CollectionPublicationFailure failure;
  final String message;

  @override
  String toString() =>
      'CollectionPublicationException(${failure.name}): $message';
}
