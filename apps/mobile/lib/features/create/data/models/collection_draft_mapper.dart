import '../../domain/entities/collection_draft_data.dart';
import '../../domain/entities/collection_item_draft.dart';
import '../../domain/entities/publisher_ref.dart';

/// Strict, symmetric JSON codec for `CollectionDraftData`
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §9 "Mapper и schema version"). A
/// future major schema version this build does not understand is rejected
/// rather than guessed at; unknown fields on a still-understood version
/// round-trip through [CollectionDraftData.unknownFields] instead of being
/// silently dropped.
class CollectionDraftMapper {
  const CollectionDraftMapper._();

  static const Set<String> _knownKeys = <String>{
    'schema_version',
    'publisher_ref',
    'area_label',
    'area_id',
    'anchor_latitude',
    'anchor_longitude',
    'budget_tier',
    'sections',
    'items',
    'composition_review',
  };

  static CollectionDraftData fromJson(
    Object? raw, {
    required CollectionDraftData defaults,
  }) {
    if (raw is! Map) return defaults;
    final Map<String, Object?> json = raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final int version = _int(json['schema_version']) ?? 1;
    if (version > CollectionDraftData.currentSchemaVersion) {
      throw const FormatException(
        'Unsupported Collection draft schema version',
      );
    }
    final Map<String, Object?> unknownFields = <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
    };
    return CollectionDraftData(
      schemaVersion: CollectionDraftData.currentSchemaVersion,
      publisherRef:
          _publisherRef(json['publisher_ref']) ?? defaults.publisherRef,
      areaLabel: _text(json['area_label']) ?? defaults.areaLabel,
      areaId: _text(json['area_id']),
      anchorLatitude: _double(json['anchor_latitude']),
      anchorLongitude: _double(json['anchor_longitude']),
      budgetTier: _enumValue<CollectionBudgetTier>(
        json['budget_tier'] as String?,
        CollectionBudgetTier.values,
      ),
      sections: _sections(json['sections']),
      items: _items(json['items']),
      compositionReview: _compositionReview(json['composition_review']),
      unknownFields: unknownFields,
    );
  }

  static Map<String, Object?> toJson(CollectionDraftData value) {
    final CollectionCompositionReview? review = value.compositionReview;
    return <String, Object?>{
      ...value.unknownFields,
      'schema_version': CollectionDraftData.currentSchemaVersion,
      'publisher_ref': _publisherRefJson(value.publisherRef),
      'area_label': value.areaLabel,
      'area_id': value.areaId,
      'anchor_latitude': value.anchorLatitude,
      'anchor_longitude': value.anchorLongitude,
      'budget_tier': value.budgetTier?.name,
      'sections': value.sections.map(_sectionJson).toList(growable: false),
      'items': value.items.map(_itemJson).toList(growable: false),
      'composition_review': review == null
          ? null
          : _compositionReviewJson(review),
    };
  }

  static List<CollectionSectionDraft> _sections(Object? raw) {
    if (raw is! List) return const <CollectionSectionDraft>[];
    return raw
        .whereType<Map>()
        .map((Map entry) {
          final String? id = _text(entry['id']);
          final int? order = _int(entry['order']);
          if (id == null || order == null) return null;
          return CollectionSectionDraft(
            id: id,
            title: _text(entry['title']) ?? '',
            order: order,
          );
        })
        .whereType<CollectionSectionDraft>()
        .toList(growable: false);
  }

  static Map<String, Object?> _sectionJson(CollectionSectionDraft section) {
    return <String, Object?>{
      'id': section.id,
      'title': section.title,
      'order': section.order,
    };
  }

  static List<CollectionItemDraft> _items(Object? raw) {
    if (raw is! List) return const <CollectionItemDraft>[];
    return raw
        .whereType<Map>()
        .map(_item)
        .whereType<CollectionItemDraft>()
        .toList(growable: false);
  }

  static CollectionItemDraft? _item(Map raw) {
    final String? id = _text(raw['id']);
    final String? objectId = _text(raw['object_id']);
    final int? order = _int(raw['order']);
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
        objectType == null ||
        sourceStatus == null) {
      return null;
    }
    return CollectionItemDraft(
      id: id,
      ref: CollectionObjectRef(objectId: objectId, objectType: objectType),
      snapshot: _snapshot(raw['snapshot']),
      sourceStatus: sourceStatus,
      order: order,
      sectionId: _text(raw['section_id']),
      curatorNote: _text(raw['curator_note']) ?? '',
      highlight: raw['highlight'] as bool? ?? false,
    );
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
      'snapshot': _snapshotJson(item.snapshot),
    };
  }

  static CollectionItemSnapshotDraft _snapshot(Object? raw) {
    if (raw is! Map) return const CollectionItemSnapshotDraft(title: '');
    return CollectionItemSnapshotDraft(
      title: _text(raw['title']) ?? '',
      coverMediaId: _text(raw['cover_media_id']),
      categoryLabel: _text(raw['category_label']),
      publisherRef: _publisherRef(raw['publisher_ref']),
      priceFromMinorUnits: _int(raw['price_from_minor_units']),
      currency: _text(raw['currency']),
      checkedAtUtc: _dateTime(raw['checked_at_utc']),
    );
  }

  static Map<String, Object?> _snapshotJson(
    CollectionItemSnapshotDraft snapshot,
  ) {
    final PublisherRef? publisherRef = snapshot.publisherRef;
    return <String, Object?>{
      'title': snapshot.title,
      'cover_media_id': snapshot.coverMediaId,
      'category_label': snapshot.categoryLabel,
      'publisher_ref': publisherRef == null
          ? null
          : _publisherRefJson(publisherRef),
      'price_from_minor_units': snapshot.priceFromMinorUnits,
      'currency': snapshot.currency,
      'checked_at_utc': snapshot.checkedAtUtc?.toIso8601String(),
    };
  }

  static CollectionCompositionReview? _compositionReview(Object? raw) {
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

  static Map<String, Object?> _compositionReviewJson(
    CollectionCompositionReview review,
  ) {
    return <String, Object?>{
      'draft_revision': review.draftRevision,
      'reviewed_at_utc': review.reviewedAtUtc.toIso8601String(),
      'acknowledged_unavailable_stable_keys': review
          .acknowledgedUnavailableStableKeys
          .toList(growable: false),
    };
  }

  static PublisherRef? _publisherRef(Object? raw) {
    if (raw is! Map) return null;
    final String? id = _text(raw['id']);
    if (id == null) return null;
    final PublisherType type =
        _enumValue<PublisherType>(
          raw['type'] as String?,
          PublisherType.values,
        ) ??
        PublisherType.user;
    return PublisherRef(type: type, id: id);
  }

  static Map<String, Object?> _publisherRefJson(PublisherRef ref) {
    return <String, Object?>{'type': ref.type.name, 'id': ref.id};
  }

  static T? _enumValue<T extends Enum>(String? name, List<T> values) {
    if (name == null) return null;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _double(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
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
