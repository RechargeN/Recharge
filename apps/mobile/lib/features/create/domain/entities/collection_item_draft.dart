import 'publisher_ref.dart';

/// v1 (CLG-CRT-01) is bounded to five stable listing types
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §3.12, §9, Вопрос 20).
/// `bookableSession` here is the offering/service itself (sauna, court,
/// photo studio) — it outlives any single booked slot. `event`, `activity`
/// and `findPeople` are intentionally excluded until CLG-CRT-0x defines how
/// to show their "upcoming date" state instead of a binary ready/unavailable.
enum CollectionCatalogObjectType {
  place,
  route,
  bookableSession,
  classWorkshop,
  rental,
}

enum CollectionSourceStatus { ready, stale, unavailable }

/// Id-only reference to an existing published catalog object (ADR id-only
/// links invariant). Never a free-text place or external URL.
class CollectionObjectRef {
  const CollectionObjectRef({required this.objectId, required this.objectType});

  final String objectId;
  final CollectionCatalogObjectType objectType;

  /// Stable dedupe key used by `addItem`/`excludeRefs`/mapper invariants.
  String get stableKey => '${objectType.name}:$objectId';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionObjectRef &&
          other.objectId == objectId &&
          other.objectType == objectType;

  @override
  int get hashCode => Object.hash(objectId, objectType);
}

/// Cached, best-effort fallback used only for fast card rendering.
/// Never carries geo — the mini-map only ever reads a live public
/// projection (§3.5, §9, CLG-AC-28).
class CollectionItemSnapshotDraft {
  const CollectionItemSnapshotDraft({
    required this.title,
    this.coverMediaId,
    this.categoryLabel,
    this.publisherRef,
    this.priceFromMinorUnits,
    this.currency,
    this.checkedAtUtc,
  });

  final String title;
  final String? coverMediaId;
  final String? categoryLabel;
  final PublisherRef? publisherRef;
  final int? priceFromMinorUnits;
  final String? currency;
  final DateTime? checkedAtUtc;
}

class CollectionItemDraft {
  const CollectionItemDraft({
    required this.id,
    required this.ref,
    required this.snapshot,
    required this.sourceStatus,
    required this.order,
    this.sectionId,
    this.curatorNote = '',
    this.highlight = false,
  });

  /// Stable local id of the item itself (ULID at publish); never equal to
  /// `ref.objectId`.
  final String id;
  final CollectionObjectRef ref;
  final CollectionItemSnapshotDraft snapshot;
  final CollectionSourceStatus sourceStatus;
  final int order;
  final String? sectionId;
  final String curatorNote;
  final bool highlight;

  CollectionItemDraft copyWith({
    String? id,
    CollectionObjectRef? ref,
    CollectionItemSnapshotDraft? snapshot,
    CollectionSourceStatus? sourceStatus,
    int? order,
    String? sectionId,
    bool clearSectionId = false,
    String? curatorNote,
    bool? highlight,
  }) {
    return CollectionItemDraft(
      id: id ?? this.id,
      ref: ref ?? this.ref,
      snapshot: snapshot ?? this.snapshot,
      sourceStatus: sourceStatus ?? this.sourceStatus,
      order: order ?? this.order,
      sectionId: clearSectionId ? null : (sectionId ?? this.sectionId),
      curatorNote: curatorNote ?? this.curatorNote,
      highlight: highlight ?? this.highlight,
    );
  }
}
