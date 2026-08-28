import 'package:characters/characters.dart';

import '../entities/collection_draft_data.dart';
import '../entities/collection_item_draft.dart';
import '../entities/collection_validation_issue.dart';
import '../entities/create_draft_entity.dart';

/// Structural/content validation from COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md
/// §11 "Блокирует публикацию" that is checkable from the entity alone.
///
/// Capability guards (§6), live `sourceStatus` resolution and revision-
/// freshness of `CollectionCompositionReview` (§9, CLG-AC-09/10) belong to
/// the application/coordinator layer that reads through
/// `CollectionItemResolutionRepository` — they are out of scope for this
/// pure domain usecase and are not implemented here.
///
/// Thresholds are constructor parameters, not literals baked into the logic,
/// so the eventual `collection_create_config.dart` (§15) can inject the
/// configured values without changing this class. The defaults below match
/// the Approved values (Вопрос 4, Вопрос 7).
class ValidateCollectionDraftUseCase {
  const ValidateCollectionDraftUseCase({
    this.minPublishableItemCount = 3,
    this.curatorNoteMaxLength = 300,
    this.selfPublisherShareWarningThreshold = 0.5,
    this.itemCountSoftWarningThreshold = 30,
  });

  final int minPublishableItemCount;
  final int curatorNoteMaxLength;

  /// Вопрос 3 — non-blocking self-promotion warning: share of ready items
  /// whose publisher matches the Collection's own publisher, at or above
  /// which the author is nudged (never blocked).
  final double selfPublisherShareWarningThreshold;

  /// Вопрос 5 — soft warning starts on the (threshold + 1)-th item; the
  /// count itself stays `без лимита` (§3.8) — this never blocks publish.
  final int itemCountSoftWarningThreshold;

  List<CollectionValidationIssue> call(CreateDraftEntity draft) {
    if (draft.objectType != CreateObjectType.collection) {
      return const <CollectionValidationIssue>[];
    }
    final List<CollectionValidationIssue> issues =
        <CollectionValidationIssue>[];
    void error(String code, String section, String field, String message) {
      issues.add(
        CollectionValidationIssue(
          code: code,
          sectionId: section,
          fieldId: field,
          message: message,
        ),
      );
    }
    void warning(String code, String section, String field, String message) {
      issues.add(
        CollectionValidationIssue(
          code: code,
          sectionId: section,
          fieldId: field,
          message: message,
          severity: CollectionValidationSeverity.warning,
        ),
      );
    }

    final CollectionDraftData? data = draft.collectionData;
    if (data == null) {
      error(
        'details_missing',
        'basics',
        'collectionData',
        'Collection details are missing',
      );
      return issues;
    }

    if (draft.title.trim().isEmpty) {
      error('title_required', 'basics', 'title', 'Add a title');
    }
    if (data.areaLabel.trim().isEmpty) {
      error('area_required', 'basics', 'areaLabel', 'Add an area or city');
    }

    if (data.items.length < minPublishableItemCount) {
      error(
        'min_items',
        'items',
        'items',
        'Add at least $minPublishableItemCount items',
      );
    }

    final Set<String> sectionIds = data.sections
        .map((CollectionSectionDraft section) => section.id)
        .toSet();
    final Set<String> seenStableKeys = <String>{};
    for (final CollectionItemDraft item in data.items) {
      if (!seenStableKeys.add(item.ref.stableKey)) {
        error(
          'duplicate_item',
          'items',
          'items',
          'Item ${item.ref.stableKey} is added more than once',
        );
      }
      final String? sectionId = item.sectionId;
      if (sectionId != null && !sectionIds.contains(sectionId)) {
        error(
          'orphan_section',
          'items',
          'sectionId',
          'Item ${item.id} points to a section that does not exist',
        );
      }
      if (item.curatorNote.characters.length > curatorNoteMaxLength) {
        error(
          'curator_note_length',
          'items',
          'curatorNote',
          'Curator note cannot exceed $curatorNoteMaxLength characters',
        );
      }
      if (item.curatorNote.trim().isEmpty) {
        warning(
          'curator_note_empty',
          'items',
          'curatorNote',
          'Say why "${item.snapshot.title}" is in this Collection',
        );
      }
    }

    if (data.items.length > itemCountSoftWarningThreshold) {
      warning(
        'item_count_high',
        'items',
        'items',
        'This Collection has ${data.items.length} items — consider '
            'grouping them into sections or splitting into more than one '
            'Collection',
      );
    }

    if (data.items.isNotEmpty) {
      final int readyCount = data.items
          .where(
            (CollectionItemDraft item) =>
                item.sourceStatus == CollectionSourceStatus.ready,
          )
          .length;
      if (readyCount > 0) {
        final int selfPublishedCount = data.items
            .where(
              (CollectionItemDraft item) =>
                  item.sourceStatus == CollectionSourceStatus.ready &&
                  item.snapshot.publisherRef == data.publisherRef,
            )
            .length;
        if (selfPublishedCount / readyCount >=
            selfPublisherShareWarningThreshold) {
          warning(
            'self_publisher_share_high',
            'items',
            'items',
            'Most items in this Collection are your own — consider adding '
                'independent picks too',
          );
        }
      }
    }

    final Set<String> unavailableStableKeys = data.items
        .where(
          (CollectionItemDraft item) =>
              item.sourceStatus == CollectionSourceStatus.unavailable,
        )
        .map((CollectionItemDraft item) => item.ref.stableKey)
        .toSet();
    final CollectionCompositionReview? review = data.compositionReview;
    if (review == null) {
      error(
        'composition_review_missing',
        'publish',
        'compositionReview',
        'Review the live composition before publishing',
      );
    } else if (!unavailableStableKeys.every(
      review.acknowledgedUnavailableStableKeys.contains,
    )) {
      error(
        'composition_review_stale',
        'publish',
        'compositionReview',
        'Some unavailable items were not part of the last review',
      );
    }

    return issues;
  }
}
