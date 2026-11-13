/// Discover-owned occurrence of a published Event
/// (`docs/product/discover/DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §2.2), per the
/// canonical `scheduleMode`/occurrence model in
/// `EVENT_CLASSIFICATION_SPEC.md` §8/§17.4. Header/Metrics/CTA on a
/// `PublishedEventDiscoveryEntity` resolve through its
/// `displayOccurrenceId` into one of these — never through a bare
/// start/end pair — so a multi-date/recurring Event cannot silently lose
/// its occurrence identity: "Multi-date/recurring Booking всегда
/// ссылается на occurrence ID" (`EVENT_CLASSIFICATION_SPEC.md:1066`).
class EventOccurrence {
  EventOccurrence({
    required this.id,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.status,
    this.bookingRef,
  }) : assert(id != '', 'EventOccurrence.id must not be empty') {
    if (!endAtUtc.isAfter(startAtUtc)) {
      throw ArgumentError('EventOccurrence.endAtUtc must be after startAtUtc');
    }
  }

  final String id;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final EventOccurrenceStatus status;

  /// E2: set when this occurrence is bookable through Recharge (internal
  /// registration). Only a reference: terms and availability come from Booking.
  final EventBookingRef? bookingRef;
}

/// Reference to free internal Booking of one exact occurrence, as the server
/// Catalog derived it. The client never computes pool ids or terms.
final class EventBookingRef {
  const EventBookingRef({
    required this.eventId,
    required this.occurrenceId,
    this.channel,
  });

  final String eventId;
  final String occurrenceId;
  final String? channel;
}

/// Canonical occurrence lifecycle (`EVENT_CLASSIFICATION_SPEC.md` §17.4).
/// Completed-ness is deliberately not a third state here — the source spec
/// derives it from end time plus a grace period, computed where the
/// occurrence is displayed, not stored.
enum EventOccurrenceStatus { scheduled, cancelled }

/// Canonical schedule mode (`EVENT_CLASSIFICATION_SPEC.md:401-405`).
enum EventScheduleMode { oneTime, multiDate, recurring }
