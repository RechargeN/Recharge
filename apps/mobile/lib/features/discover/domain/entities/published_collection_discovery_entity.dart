/// Discover-owned read model for an active Collection version
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §13, §14). Built once, on publish,
/// by `CollectionPublicationDiscoveryAdapter` from Create's immutable
/// publish bundle — Discover never imports `CollectionDraftData` or any
/// other Create domain type, so every field here is a primitive, matching
/// how `PublishedRouteDiscoveryEntity` stores enums as plain strings rather
/// than importing Create's enum types.
class PublishedCollectionDiscoveryEntity {
  const PublishedCollectionDiscoveryEntity({
    required this.collectionId,
    required this.versionId,
    required this.title,
    required this.shortDescription,
    required this.publisherName,
    required this.marketCityId,
    required this.areaLabel,
    this.areaId,
    this.budgetTier,
    required this.coverImage,
    required this.sections,
    required this.items,
    required this.publishedAtUtc,
  });

  final String collectionId;
  final String versionId;

  final String title;
  final String shortDescription;
  final String publisherName;
  final String marketCityId;
  final String areaLabel;
  final String? areaId;

  /// `free` / `low` / `medium` / `high`, or null if never set (Вопрос 18).
  final String? budgetTier;
  final String coverImage;

  final List<PublishedCollectionSectionRef> sections;
  final List<PublishedCollectionItemRef> items;
  final DateTime publishedAtUtc;

  int get itemCount => items.length;

  /// A Collection is never a point object — see §13 "Object type". This
  /// only guards against an empty/broken index entry, not against a
  /// missing map point (there never is one).
  bool get isCoherent =>
      collectionId.isNotEmpty && versionId.isNotEmpty && items.isNotEmpty;
}

class PublishedCollectionSectionRef {
  const PublishedCollectionSectionRef({
    required this.id,
    required this.title,
    required this.order,
  });

  final String id;
  final String title;
  final int order;
}

/// One entry of an active Collection's composition. `objectType` is the
/// wire-safe name of Create's `CollectionCatalogObjectType` — stored as a
/// plain string, not the enum itself, to keep this file free of a Create
/// domain import.
class PublishedCollectionItemRef {
  const PublishedCollectionItemRef({
    required this.objectId,
    required this.objectType,
    this.sectionId,
    required this.order,
    required this.curatorNote,
    required this.highlight,
  });

  final String objectId;
  final String objectType;
  final String? sectionId;
  final int order;
  final String curatorNote;
  final bool highlight;

  String get stableKey => '$objectType:$objectId';
}
