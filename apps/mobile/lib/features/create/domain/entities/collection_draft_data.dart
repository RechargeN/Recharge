import 'collection_item_draft.dart';
import 'publisher_ref.dart';

enum CollectionBudgetTier { free, low, medium, high }

class CollectionSectionDraft {
  const CollectionSectionDraft({
    required this.id,
    required this.title,
    required this.order,
  });

  final String id;
  final String title;
  final int order;

  CollectionSectionDraft copyWith({String? id, String? title, int? order}) {
    return CollectionSectionDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
    );
  }
}

/// Confirms the author actually looked at the live-resolved composition of a
/// specific draft revision and knowingly accepted its unavailable items
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §2, §9). Any composition mutation
/// invalidates it — see the coordinator layer, not this entity.
class CollectionCompositionReview {
  const CollectionCompositionReview({
    required this.draftRevision,
    required this.reviewedAtUtc,
    required this.acknowledgedUnavailableStableKeys,
  });

  final int draftRevision;
  final DateTime reviewedAtUtc;
  final Set<String> acknowledgedUnavailableStableKeys;
}

class CollectionDraftData {
  const CollectionDraftData({
    required this.schemaVersion,
    required this.publisherRef,
    required this.areaLabel,
    this.areaId,
    this.anchorLatitude,
    this.anchorLongitude,
    this.budgetTier,
    this.sections = const <CollectionSectionDraft>[],
    this.items = const <CollectionItemDraft>[],
    this.compositionReview,
    this.unknownFields = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final PublisherRef publisherRef;

  /// Display/fallback text. Not the ranking authority — see [areaId].
  final String areaLabel;

  /// Canonical id used for exact-match ranking boost (§10). Optional: not
  /// every area has a canonical id yet.
  final String? areaId;

  /// Single reference point for the whole area this guide covers — used for
  /// area-boost ranking and as the fallback center for
  /// `CollectionDetailsMiniMap` when no item has its own live geo yet.
  /// Not the location of any individual item.
  final double? anchorLatitude;
  final double? anchorLongitude;
  final CollectionBudgetTier? budgetTier;
  final List<CollectionSectionDraft> sections;
  final List<CollectionItemDraft> items;
  final CollectionCompositionReview? compositionReview;

  /// Round-trip preservation for a newer minor/patch schema this build does
  /// not understand yet (§9 "Mapper и schema version") — never silently
  /// dropped, never guessed at.
  final Map<String, Object?> unknownFields;

  factory CollectionDraftData.defaults({required PublisherRef publisherRef}) {
    return CollectionDraftData(
      schemaVersion: CollectionDraftData.currentSchemaVersion,
      publisherRef: publisherRef,
      areaLabel: '',
    );
  }

  CollectionDraftData copyWith({
    int? schemaVersion,
    PublisherRef? publisherRef,
    String? areaLabel,
    String? areaId,
    bool clearAreaId = false,
    double? anchorLatitude,
    double? anchorLongitude,
    bool clearAnchor = false,
    CollectionBudgetTier? budgetTier,
    bool clearBudgetTier = false,
    List<CollectionSectionDraft>? sections,
    List<CollectionItemDraft>? items,
    CollectionCompositionReview? compositionReview,
    bool clearCompositionReview = false,
    Map<String, Object?>? unknownFields,
  }) {
    return CollectionDraftData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      publisherRef: publisherRef ?? this.publisherRef,
      areaLabel: areaLabel ?? this.areaLabel,
      areaId: clearAreaId ? null : (areaId ?? this.areaId),
      anchorLatitude: clearAnchor
          ? null
          : (anchorLatitude ?? this.anchorLatitude),
      anchorLongitude: clearAnchor
          ? null
          : (anchorLongitude ?? this.anchorLongitude),
      budgetTier: clearBudgetTier ? null : (budgetTier ?? this.budgetTier),
      sections: sections ?? this.sections,
      items: items ?? this.items,
      compositionReview: clearCompositionReview
          ? null
          : (compositionReview ?? this.compositionReview),
      unknownFields: unknownFields ?? this.unknownFields,
    );
  }
}
