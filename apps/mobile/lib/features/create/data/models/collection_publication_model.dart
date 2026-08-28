import '../../domain/entities/collection_draft_data.dart';
import '../../domain/entities/collection_item_draft.dart';
import '../../domain/entities/collection_publication_data.dart';
import '../../domain/entities/publisher_ref.dart';

/// Deterministic, lossless JSON codec for a publish bundle. Originally
/// hash-only (§12 idempotency payload hash); CLG-PST-01 made it fully
/// round-trippable (added the item snapshot fields `toJson` previously
/// dropped — `coverMediaId`/`categoryLabel`/`checkedAtUtc`/full
/// `publisherRef`) so the persisted store can rebuild an exact
/// `CollectionPublishBundle`, not just a hash of an approximation. That
/// also makes the idempotency hash itself more precise: two bundles that
/// previously differed only in a dropped field hashed identically before
/// this change.
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

  /// Returns `null` on any structurally invalid input — a missing/mistyped
  /// required field, an unrecognized enum name — never a partially-built
  /// bundle. The caller (the persisted store's mapper) treats `null` as one
  /// corrupt record to isolate, not a reason to throw past it.
  static CollectionPublishBundle? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, Object?> json = raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    // Required-field reads use `_requiredText`, not `_text`: an empty
    // string is valid content for e.g. `shortDescription` on a sparsely
    // filled draft — collapsing it to "missing" (as `_text` deliberately
    // does for genuinely optional fields like `areaId`) would reject a
    // perfectly good record as corrupt.
    final String? collectionId = _requiredText(json['collection_id']);
    final String? collectionVersionId = _requiredText(
      json['collection_version_id'],
    );
    final PublisherRef? publisherRef = _publisherRef(json['publisher_ref']);
    final String? title = _requiredText(json['title']);
    final String? shortDescription = _requiredText(json['short_description']);
    final String? fullDescription = _requiredText(json['full_description']);
    final String? marketCityId = _requiredText(json['market_city_id']);
    final String? areaLabel = _requiredText(json['area_label']);
    final String? visibility = _requiredText(json['visibility']);
    final String? publishAttemptId = _requiredText(
      json['publish_attempt_id'],
    );
    final CollectionCompositionReview? review = _review(
      json['composition_review'],
    );
    if (collectionId == null ||
        collectionVersionId == null ||
        publisherRef == null ||
        title == null ||
        shortDescription == null ||
        fullDescription == null ||
        marketCityId == null ||
        areaLabel == null ||
        visibility == null ||
        publishAttemptId == null ||
        review == null) {
      return null;
    }
    final List<CollectionSectionDraft>? sections = _sections(
      json['sections'],
    );
    final List<CollectionItemDraft>? items = _items(json['items']);
    if (sections == null || items == null) return null;
    return CollectionPublishBundle(
      collectionId: collectionId,
      collectionVersionId: collectionVersionId,
      publisherRef: publisherRef,
      title: title,
      shortDescription: shortDescription,
      fullDescription: fullDescription,
      coverMediaId: _text(json['cover_media_id']),
      marketCityId: marketCityId,
      areaLabel: areaLabel,
      areaId: _text(json['area_id']),
      budgetTier: _enumValue<CollectionBudgetTier>(
        json['budget_tier'] as String?,
        CollectionBudgetTier.values,
      ),
      visibility: visibility,
      sections: sections,
      items: items,
      compositionReview: review,
      publishAttemptId: publishAttemptId,
    );
  }

  static Map<String, Object?> _sectionJson(CollectionSectionDraft section) {
    return <String, Object?>{
      'id': section.id,
      'title': section.title,
      'order': section.order,
    };
  }

  static List<CollectionSectionDraft>? _sections(Object? raw) {
    if (raw is! List) return null;
    final List<CollectionSectionDraft> result = <CollectionSectionDraft>[];
    for (final Object? entry in raw) {
      if (entry is! Map) return null;
      final String? id = _requiredText(entry['id']);
      final int? order = _int(entry['order']);
      if (id == null || order == null) return null;
      result.add(
        CollectionSectionDraft(id: id, title: _text(entry['title']) ?? '', order: order),
      );
    }
    return List<CollectionSectionDraft>.unmodifiable(result);
  }

  static Map<String, Object?> _itemJson(CollectionItemDraft item) {
    final PublisherRef? snapshotPublisher = item.snapshot.publisherRef;
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
      'cover_media_id': item.snapshot.coverMediaId,
      'category_label': item.snapshot.categoryLabel,
      'snapshot_publisher_ref': snapshotPublisher == null
          ? null
          : _publisherRefJson(snapshotPublisher),
      'price_from_minor_units': item.snapshot.priceFromMinorUnits,
      'currency': item.snapshot.currency,
      'checked_at_utc': item.snapshot.checkedAtUtc?.toIso8601String(),
    };
  }

  static List<CollectionItemDraft>? _items(Object? raw) {
    if (raw is! List) return null;
    final List<CollectionItemDraft> result = <CollectionItemDraft>[];
    for (final Object? entry in raw) {
      if (entry is! Map) return null;
      final CollectionItemDraft? item = _item(entry);
      if (item == null) return null;
      result.add(item);
    }
    return List<CollectionItemDraft>.unmodifiable(result);
  }

  static CollectionItemDraft? _item(Map raw) {
    final String? id = _requiredText(raw['id']);
    final String? objectId = _requiredText(raw['object_id']);
    final int? order = _int(raw['order']);
    final String? title = _requiredText(raw['title']);
    final CollectionCatalogObjectType? objectType =
        _enumValue<CollectionCatalogObjectType>(
          raw['object_type'] as String?,
          CollectionCatalogObjectType.values,
        );
    final CollectionSourceStatus? sourceStatus =
        _enumValue<CollectionSourceStatus>(
          raw['source_status'] as String?,
          CollectionSourceStatus.values,
        );
    if (id == null ||
        objectId == null ||
        order == null ||
        title == null ||
        objectType == null ||
        sourceStatus == null) {
      return null;
    }
    return CollectionItemDraft(
      id: id,
      ref: CollectionObjectRef(objectId: objectId, objectType: objectType),
      snapshot: CollectionItemSnapshotDraft(
        title: title,
        coverMediaId: _text(raw['cover_media_id']),
        categoryLabel: _text(raw['category_label']),
        publisherRef: _publisherRef(raw['snapshot_publisher_ref']),
        priceFromMinorUnits: _int(raw['price_from_minor_units']),
        currency: _text(raw['currency']),
        checkedAtUtc: _dateTime(raw['checked_at_utc']),
      ),
      sourceStatus: sourceStatus,
      order: order,
      sectionId: _text(raw['section_id']),
      curatorNote: _text(raw['curator_note']) ?? '',
      highlight: raw['highlight'] as bool? ?? false,
    );
  }

  static Map<String, Object?> _reviewJson(CollectionCompositionReview review) {
    return <String, Object?>{
      'draft_revision': review.draftRevision,
      'reviewed_at_utc': review.reviewedAtUtc.toIso8601String(),
      'acknowledged_unavailable_stable_keys':
          review.acknowledgedUnavailableStableKeys.toList()..sort(),
    };
  }

  static CollectionCompositionReview? _review(Object? raw) {
    if (raw is! Map) return null;
    final int? draftRevision = _int(raw['draft_revision']);
    final DateTime? reviewedAtUtc = _dateTime(raw['reviewed_at_utc']);
    if (draftRevision == null || reviewedAtUtc == null) return null;
    final Object? keysRaw = raw['acknowledged_unavailable_stable_keys'];
    final Set<String> keys = keysRaw is List
        ? keysRaw.whereType<String>().toSet()
        : const <String>{};
    return CollectionCompositionReview(
      draftRevision: draftRevision,
      reviewedAtUtc: reviewedAtUtc,
      acknowledgedUnavailableStableKeys: keys,
    );
  }

  static Map<String, Object?> _publisherRefJson(PublisherRef ref) {
    return <String, Object?>{'type': ref.type.name, 'id': ref.id};
  }

  static PublisherRef? _publisherRef(Object? raw) {
    if (raw is! Map) return null;
    final String? id = _requiredText(raw['id']);
    if (id == null) return null;
    final PublisherType? type = _enumValue<PublisherType>(
      raw['type'] as String?,
      PublisherType.values,
    );
    if (type == null) return null;
    return PublisherRef(type: type, id: id);
  }

  static T? _enumValue<T extends Enum>(String? name, List<T> values) {
    if (name == null) return null;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// For genuinely optional fields (`areaId`, `coverMediaId`,
  /// `categoryLabel`, `currency`, `sectionId`) — an empty string and
  /// "absent" are interchangeable there, so both collapse to `null`.
  static String? _text(Object? value) {
    if (value is! String) return null;
    return value.isEmpty ? null : value;
  }

  /// For required, non-nullable `String` fields — an empty string is
  /// valid, round-trippable content (a sparsely filled draft's
  /// `shortDescription`, say), not a signal that the field is missing.
  /// Only a non-string/absent value is treated as invalid here.
  static String? _requiredText(Object? value) {
    return value is String ? value : null;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
