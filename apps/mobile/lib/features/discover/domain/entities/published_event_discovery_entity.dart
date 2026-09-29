import 'discover_item_entity.dart' show DurationConfidence;
import 'event_occurrence.dart';
import 'published_event_program_item.dart';
import 'publisher_verification_display_state.dart';

/// Discover-owned typed read projection for a published Event
/// (`docs/product/discover/DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §2.4), built by
/// the mock-first `published_event_discovery_local_datasource.dart` for
/// this slice — not by a live Create → Discover publish pipeline, which
/// does not exist yet for Event (or for any Discover type: the whole
/// Discover surface is mock-data today).
///
/// Deliberately not an extension of the legacy `DiscoverItemEntity`:
/// `DISCOVER_DETAILS_SYSTEM_SPEC.md` §9 requires a typed family read
/// model instead of growing the legacy point-feed entity, the same
/// pattern already used by `PublishedRentalDiscoveryEntity` — primitives
/// and this feature's own enums only, no Create-domain import
/// (OBJ-AC-05).
///
/// The field list here is normative for this slice's Approval, not
/// representative — every field maps to a concrete consumer cited in its
/// doc comment below.
class PublishedEventDiscoveryEntity {
  PublishedEventDiscoveryEntity({
    required this.eventId,
    required this.publisherId,
    required this.publisherType,
    required this.publisherName,
    this.publisherHandle = '',
    this.publisherVerification = PublisherVerificationDisplayState.none,
    required this.title,
    required this.subtitle,
    required this.fullDescription,
    required this.category,
    this.subcategory = '',
    required this.city,
    this.marketCityId = '',
    this.coverImageUrl = '',
    this.galleryImageUrls = const <String>[],
    this.galleryAltText = const <String, String>{},
    this.venueName = '',
    this.addressLine = '',
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.priceAmount,
    required this.isFree,
    required this.currencyCode,
    this.externalBookingUrl,
    this.participantsCount,
    this.capacity,
    this.durationMinutes,
    this.durationConfidence = DurationConfidence.unknown,
    required this.scheduleMode,
    required this.occurrences,
    required this.displayOccurrenceId,
    required this.timezoneId,
    this.programItems = const <PublishedEventProgramItem>[],
    required this.publishedAtUtc,
  }) : assert(
         eventId != '',
         'PublishedEventDiscoveryEntity.eventId must not be empty',
       ),
       assert(distanceKm >= 0, 'distanceKm must not be negative'),
       assert(priceAmount >= 0),
       assert(participantsCount == null || participantsCount >= 0),
       assert(capacity == null || capacity > 0),
       assert(durationMinutes == null || durationMinutes > 0) {
    // Imperative (not `assert`) because these two invariants involve a
    // method call (`Iterable.any`), which a `const`-eligible assert
    // cannot express, and because — like `TimeSlot`'s constructor — they
    // are real data-integrity checks worth keeping in release builds,
    // not just debug-mode sanity checks.
    if (occurrences.isEmpty) {
      throw ArgumentError(
        'An Event without a confirmed occurrence is not published '
        '(EVENT_CLASSIFICATION_SPEC.md:70,442) — occurrences must not be '
        'empty.',
      );
    }
    if (!occurrences.any((EventOccurrence o) => o.id == displayOccurrenceId)) {
      throw ArgumentError(
        'displayOccurrenceId must resolve to an entry in occurrences — a '
        'dangling id is a data bug upstream.',
      );
    }
  }

  final String eventId;

  /// `'user' | 'page'` — wire-safe transcription of Create's
  /// `PublisherType`, same convention `PublishedRentalDiscoveryEntity`
  /// already uses (no Create-domain enum import).
  final String publisherId;
  final String publisherType;

  /// Organizer card name/handle.
  final String publisherName;
  final String publisherHandle;

  /// §2.3 — badge renders iff `!= none`.
  final PublisherVerificationDisplayState publisherVerification;

  final String title;

  /// Required by `FavoriteItemEntity` construction
  /// (`discover_details_page.dart:475`).
  final String subtitle;

  /// About card body — same semantics as Create's `fullDescription`
  /// (`event_create_block.dart:120`), not a new concept.
  final String fullDescription;

  /// Required by `FavoriteItemEntity` construction (`:477`).
  final String category;
  final String subcategory;

  /// Required by `FavoriteItemEntity` construction (`:476`).
  final String city;
  final String marketCityId;

  /// Hero `PageView` source: `[coverImageUrl, ...galleryImageUrls]` with
  /// `coverImageUrl` de-duplicated if already present in
  /// [galleryImageUrls] by URL value.
  final String coverImageUrl;
  final List<String> galleryImageUrls;

  /// Accessibility text for hero pages, keyed by image URL — mirrors
  /// Create's `_EventGalleryEditor.altText` shape.
  final Map<String, String> galleryAltText;

  final String venueName;
  final String addressLine;
  final double latitude;
  final double longitude;

  /// Required by `FavoriteItemEntity` construction (`:479`) — without it,
  /// Save for Event fails at runtime, not just visually.
  final double distanceKm;

  final double priceAmount;
  final bool isFree;
  final String currencyCode;

  /// Primary CTA source for a priced Event (§0.7): non-null/non-empty →
  /// real external redirect via `url_launcher`, same mechanism as
  /// `rental_details_page.dart:27-49`. Null/empty → CTA hidden entirely,
  /// never a disabled placeholder.
  final String? externalBookingUrl;

  /// `null` = genuinely unknown, never displayed as `0`.
  final int? participantsCount;
  final int? capacity;

  final int? durationMinutes;
  final DurationConfidence durationConfidence;

  /// §2.2 — occurrence model. `scheduleMode`/`occurrences` are the
  /// authority; there is no flat `startsAtUtc`/`endsAtUtc` pair on this
  /// entity by design (`EVENT_CLASSIFICATION_SPEC.md` §8/§17.4).
  final EventScheduleMode scheduleMode;
  final List<EventOccurrence> occurrences;

  /// Which [occurrences] entry Header/Metrics/CTA show right now. Must
  /// resolve to a real entry in [occurrences] — callers should not treat
  /// a dangling id as anything other than a data bug upstream.
  final String displayOccurrenceId;

  /// Shared timezone for this Event and all its [programItems] — one
  /// timezone per Event, matching the source spec's own schedule model.
  final String timezoneId;

  /// §2.1 — read-only; never carries its own CTA/booking state.
  final List<PublishedEventProgramItem> programItems;

  final DateTime publishedAtUtc;

  /// Resolves [displayOccurrenceId] against [occurrences]. Returns `null`
  /// if the id does not match any occurrence — callers must treat that as
  /// a data-integrity bug (e.g. surface `DetailsUnavailableReason`
  /// upstream), not silently fall back to the first occurrence.
  EventOccurrence? get displayOccurrence {
    for (final EventOccurrence occurrence in occurrences) {
      if (occurrence.id == displayOccurrenceId) return occurrence;
    }
    return null;
  }

  /// Whether viewer actions may use the selected occurrence. Cancelled
  /// occurrences remain readable from a direct link, but must never expose
  /// Join/calendar actions or enter Scenario as a ready source.
  bool get hasActionableDisplayOccurrence =>
      displayOccurrence?.status == EventOccurrenceStatus.scheduled;
}
