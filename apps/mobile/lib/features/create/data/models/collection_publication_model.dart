import '../../domain/entities/collection_draft_data.dart';
import '../../domain/entities/collection_item_draft.dart';
import '../../domain/entities/collection_publication_data.dart';
import '../../domain/entities/publisher_ref.dart';

/// Deterministic JSON projection of a publish bundle — used today only to
/// compute the idempotency payload hash in
/// `CollectionPublicationLocalDatasource` (§12). A real backend/storage
/// adapter reuses the same shape for the actual write.
class CollectionPublicationModel {
  const CollectionPublicationModel._();

  static Map<String, Object?> toJson(CollectionPublishBundle bundle) {
    return <String, Object?>{
      'collection_id': bundle.collectionId,
      'collection_version_id': bundle.collectionVersionId,
      'publisher_ref': _publisherRefJson(bundle.publisherRef),
      'title': bundle.title,
      'short_description': bundle.shortDescription,
      'full_description': bundle.fullDescription,
      'cover_media_id': bundle.coverMediaId,
      'market_city_id': bundle.marketCityId,
      'area_label': bundle.areaLabel,
      'area_id': bundle.areaId,
      'budget_tier': bundle.budgetTier?.name,
      'visibility': bundle.visibility,
      'sections': bundle.sections.map(_sectionJson).toList(growable: false),
      'items': bundle.items.map(_itemJson).toList(growable: false),
      'composition_review': _reviewJson(bundle.compositionReview),
      'publish_attempt_id': bundle.publishAttemptId,
    };
  }

  static Map<String, Object?> _sectionJson(CollectionSectionDraft section) {
    return <String, Object?>{
      'id': section.id,
      'title': section.title,
      'order': section.order,
    };
  }

  static Map<String, Object?> _itemJson(CollectionItemDraft item) {
    return <String, Object?>{
      'id': item.id,
      'object_id': item.ref.objectId,
      'object_type': item.ref.objectType.name,
      'source_status': item.sourceStatus.name,
      'order': item.order,
      'section_id': item.sectionId,
      'curator_note': item.curatorNote,
      'highlight': item.highlight,
      'title': item.snapshot.title,
      'price_from_minor_units': item.snapshot.priceFromMinorUnits,
      'currency': item.snapshot.currency,
    };
  }

  static Map<String, Object?> _reviewJson(CollectionCompositionReview review) {
    return <String, Object?>{
      'draft_revision': review.draftRevision,
      'reviewed_at_utc': review.reviewedAtUtc.toIso8601String(),
      'acknowledged_unavailable_stable_keys':
          review.acknowledgedUnavailableStableKeys.toList()..sort(),
    };
  }

  static Map<String, Object?> _publisherRefJson(PublisherRef ref) {
    return <String, Object?>{'type': ref.type.name, 'id': ref.id};
  }
}
