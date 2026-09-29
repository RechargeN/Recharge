/// The closed set of stable catalog object types Discover Details can
/// resolve, per `docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §11
/// (DTL-D09). Mirrors `CreateObjectType.taxonomyId`
/// (`apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart`)
/// minus `quick_plan` — Quick Plan is explicitly excluded from the Discover
/// Details 10-type mapping (it has no public catalog presence to link to).
///
/// Defined here, not reused from `CreateObjectType`, because
/// `CatalogObjectRef` is a **shared app-level primitive** (used by
/// Favorites, Collection, Notifications — not router- or Create-only) and
/// must not import `features/create` (`ARCHITECTURE_BASELINE.md` rule 5:
/// `features/*` do not import each other directly; `shared/` must stay
/// dependency-free of any single feature).
enum CatalogObjectType {
  event,
  activity,
  route,
  place,
  session,
  scenario,
  findPeople,
  classWorkshop,
  rental,
  collection;

  /// The stable taxonomy ID string, identical in spelling to the
  /// corresponding `CreateObjectType.taxonomyId` value.
  String get taxonomyId {
    return switch (this) {
      CatalogObjectType.event => 'event',
      CatalogObjectType.activity => 'activity',
      CatalogObjectType.route => 'route',
      CatalogObjectType.place => 'place',
      CatalogObjectType.session => 'session',
      CatalogObjectType.scenario => 'scenario',
      CatalogObjectType.findPeople => 'find_people',
      CatalogObjectType.classWorkshop => 'class_workshop',
      CatalogObjectType.rental => 'rental',
      CatalogObjectType.collection => 'collection',
    };
  }
}

/// Parses [value] into a [CatalogObjectType], or `null` if it matches none.
///
/// Accepts both the snake_case `taxonomyId` form and the bare Dart enum
/// `.name` form (e.g. `findPeople`), case-insensitively — the same
/// leniency `createObjectTypeFromId` already applies for `CreateObjectType`
/// (`create_draft_entity.dart`), because at least one existing producer
/// (`CollectionPublicationDiscoveryAdapter`, via
/// `item.ref.objectType.name`) stores the bare `.name` form rather than
/// `taxonomyId`. Never guesses or falls back to a default type: an
/// unrecognized string returns `null`, which callers must treat as
/// `notFound`, not as any particular type.
CatalogObjectType? catalogObjectTypeFromTaxonomyId(String value) {
  final String normalized = value.trim().toLowerCase().replaceAll('-', '_');
  for (final CatalogObjectType type in CatalogObjectType.values) {
    if (type.taxonomyId == normalized ||
        type.name.toLowerCase() == normalized) {
      return type;
    }
  }
  return null;
}

/// Shared app-level reference to one catalog object —
/// `docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §11 (DTL-D09). Not a
/// router-only type: also used by Favorites, Collection item refs, and
/// Notifications wherever a link target is already known by type at
/// construction time.
///
/// Generalizes an already-Accepted pattern: `SCENARIO_BUILDER_SPEC.md`
/// independently uses `{objectType: scenario, objectId}` for Favorites and
/// Review. This type is that same shape, extended to all ten stable types.
class CatalogObjectRef {
  const CatalogObjectRef({required this.objectType, required this.objectId});

  final CatalogObjectType objectType;
  final String objectId;

  @override
  bool operator ==(Object other) {
    return other is CatalogObjectRef &&
        other.objectType == objectType &&
        other.objectId == objectId;
  }

  @override
  int get hashCode => Object.hash(objectType, objectId);

  @override
  String toString() =>
      'CatalogObjectRef(${objectType.taxonomyId}, $objectId)';
}
