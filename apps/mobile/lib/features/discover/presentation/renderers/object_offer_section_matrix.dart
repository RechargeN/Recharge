import '../../../../shared/models/catalog_object_ref.dart';

/// The three Object/Offer visual profiles (`DTL-OBJ-01` §2). Data-driven
/// membership — `ObjectOfferDetailsRenderer` never branches on
/// `CatalogObjectType` directly; it asks this file which profile a type
/// belongs to (OBJ-AC-06).
enum ObjectOfferProfile { venue, participation, offer }

/// Which profile a given catalog type renders under. Throws for any type
/// outside this slice's scope (`DTL-OBJ-01` §1.1) — a caller reaching this
/// with e.g. `session` is a routing bug upstream, not a case to render
/// something generic for.
ObjectOfferProfile objectOfferProfileFor(CatalogObjectType type) {
  return switch (type) {
    CatalogObjectType.place => ObjectOfferProfile.venue,
    CatalogObjectType.event ||
    CatalogObjectType.activity => ObjectOfferProfile.participation,
    CatalogObjectType.rental => ObjectOfferProfile.offer,
    CatalogObjectType.route ||
    CatalogObjectType.session ||
    CatalogObjectType.scenario ||
    CatalogObjectType.findPeople ||
    CatalogObjectType.classWorkshop ||
    CatalogObjectType.collection => throw ArgumentError(
      '$type has no Object/Offer profile (DTL-OBJ-01 §1.1) — '
      'ObjectOfferDetailsRenderer must not be reached for it.',
    ),
  };
}

/// Canonical section identifiers for the `offer` profile (Rental) —
/// `DTL-OBJ-01` §17.4 Details order. `venue`/`participation` do not use
/// this list: they keep today's `CompatibilityObjectRenderer` output
/// unchanged for visual/functional parity (OBJ-AC-02,
/// "Что изменилось v0.2" — DTL-OBJ-01 spec explicitly scopes Phase 1 that
/// way), so `ObjectOfferDetailsRenderer` delegates those two profiles to
/// it wholesale rather than reconstructing an equivalent layout here.
enum ObjectOfferSection {
  hero,
  inventory,
  availability,
  pricing,
  pickup,
  duration,
  publisher,
  externalCta,
}

const List<ObjectOfferSection> offerProfileSections = <ObjectOfferSection>[
  ObjectOfferSection.hero,
  ObjectOfferSection.inventory,
  ObjectOfferSection.availability,
  ObjectOfferSection.pricing,
  ObjectOfferSection.pickup,
  ObjectOfferSection.duration,
  ObjectOfferSection.publisher,
  ObjectOfferSection.externalCta,
];
