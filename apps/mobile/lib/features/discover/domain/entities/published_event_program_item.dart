/// Discover-owned read projection of one Event program item
/// (`docs/product/discover/DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §2.1). The name
/// deliberately says "Published...ProgramItem", not "ProgramItem" — this is
/// a Discover read projection of one program entry, not a second canonical
/// aggregate type alongside Event.
///
/// Deliberately has no visibility/access/inventory/pricing/booking field:
/// `EVENT_CLASSIFICATION_SPEC.md:958-960,1071` requires that a program item
/// needing any of those becomes a separate child Event with its own
/// `PublisherRef` and `parentEventRef`, not a richer
/// [PublishedEventProgramItem]. This class cannot express that violation
/// because the field does not exist here — the invariant is enforced by
/// omission, not by a runtime check.
class PublishedEventProgramItem {
  const PublishedEventProgramItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.startAtUtc,
    required this.endAtUtc,
    this.description,
  }) : assert(id != '', 'PublishedEventProgramItem.id must not be empty');

  final String id;
  final String title;
  final EventProgramItemKind kind;
  final DateTime startAtUtc;
  final DateTime endAtUtc;

  /// Free-text detail shown under [title]. Not the place for stage/room/
  /// venue linkage — `EVENT_CLASSIFICATION_SPEC.md:957` mentions stable
  /// IDs for those, deliberately left open per the slice spec §8.
  final String? description;
}

/// Wire-safe vocabulary for [PublishedEventProgramItem.kind] — exact
/// transcription of the Accepted `EVENT_CLASSIFICATION_SPEC.md:943`
/// (`act | session | screening | activity | break`), declared
/// independently here rather than imported: Discover never imports
/// `features/create/domain/entities/event_classification.dart` or any
/// other Create-domain type (`DISCOVER_DETAILS_SYSTEM_SPEC.md` §9,
/// OBJ-AC-05).
enum EventProgramItemKind {
  act('act'),
  session('session'),
  screening('screening'),
  activity('activity'),

  /// Dart reserves `break`; [wireName] carries the actual canonical
  /// string, matching the wire-vocabulary-as-plain-string convention
  /// already used elsewhere in this feature (OBJ-AC-05).
  breakTime('break');

  const EventProgramItemKind(this.wireName);

  final String wireName;

  static EventProgramItemKind? fromWireName(Object? value) {
    for (final EventProgramItemKind kind in EventProgramItemKind.values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}
