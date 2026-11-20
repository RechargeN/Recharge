import 'package:recharge/shared/primitives/time/utc_instant.dart';
import '../../shared/primitives/money/money.dart';
import '../../shared/primitives/money/currency_code.dart';
import '../../features/discover/domain/entities/discover_item_entity.dart'
    show DurationConfidence;
import '../../features/discover/domain/entities/event_occurrence.dart';
import '../../features/discover/domain/entities/published_event_discovery_entity.dart';

/// Test-only identity of the Booking-test fixture Event of the stand seed
/// (`apps/backend/functions/test/stand/stand_plan.ts`): an explicit synthetic
/// Event-outbox Event that the Booking checks book against. It exists only so
/// the default-off Booking test entry can open that exact Event by id; it is
/// not a Catalog record, carries no authority and is not the stand's Content
/// Event (C3), which is created through the Content path and is not bookable.
const String seededBookingEventId = 'evt_01JSTANDEVENTRIGAOPEN001';
const String seededBookingOccurrenceId = 'occ_01JSTANDOCCURRENCE000001';
const String seededBookingPoolId = 'pool_general';
const String seededBookingChannel = 'onsite';
const int seededBookingEventRevision = 1;

PublishedEventDiscoveryEntity seededBookingEventProjection() {
  final DateTime start = DateTime.utc(2035, 6, 1, 16);
  return PublishedEventDiscoveryEntity(
    eventId: seededBookingEventId,
    publisherId: '5d1e0000-0000-4000-8000-00000000a001',
    publisherType: 'page',
    publisherName: 'Stand Studio',
    title: 'Riga Open Air (stand fixture)',
    subtitle: 'Seeded Event for local Booking checks',
    fullDescription:
        'Seeded Event used only by the local test backend. Not a Catalog '
        'record.',
    category: 'culture',
    city: 'Riga',
    latitude: 56.9496,
    longitude: 24.1052,
    distanceKm: 0,
    priceAmount: Money(minorUnits: 0, currency: CurrencyCode.eur),
    isFree: true,
    currencyCode: 'EUR',
    durationConfidence: DurationConfidence.unknown,
    scheduleMode: EventScheduleMode.oneTime,
    occurrences: <EventOccurrence>[
      EventOccurrence(
        id: seededBookingOccurrenceId,
        startAtUtc: start,
        endAtUtc: start.add(const Duration(hours: 3)),
        status: EventOccurrenceStatus.scheduled,
      ),
    ],
    displayOccurrenceId: seededBookingOccurrenceId,
    timezoneId: 'Europe/Riga',
    publishedAtUtc: DateTime.utc(2026, 10),
  );
}

/// Debug-only: a published cloud Event opened from the Event publication test
/// page (no Discover in the cloud). Only ids and times travel in the route;
/// the server decides availability and every command. Null for bad input.
PublishedEventDiscoveryEntity? publishedTestBookingEventProjection({
  required String eventId,
  required Map<String, String> query,
}) {
  final RegExp id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  final String? occurrenceId = query['occurrence'];
  final DateTime? start = UtcInstant.tryParse(query['start'] ?? '')?.value;
  final DateTime? end = UtcInstant.tryParse(query['end'] ?? '')?.value;
  if (!id.hasMatch(eventId) ||
      occurrenceId == null ||
      !id.hasMatch(occurrenceId) ||
      start == null ||
      end == null ||
      !end.isAfter(start)) {
    return null;
  }
  final String? channel = query['channel'];
  if (channel != null && channel != 'onsite' && channel != 'online') {
    return null;
  }
  final String title = (query['title'] ?? '').trim();
  return PublishedEventDiscoveryEntity(
    eventId: eventId,
    publisherId: '',
    publisherType: 'user',
    publisherName: '',
    title: title.isEmpty ? eventId : title,
    subtitle: '',
    fullDescription: '',
    category: '',
    city: '',
    latitude: 0,
    longitude: 0,
    distanceKm: 0,
    priceAmount: Money(minorUnits: 0, currency: CurrencyCode.eur),
    isFree: true,
    currencyCode: 'EUR',
    durationConfidence: DurationConfidence.unknown,
    scheduleMode: EventScheduleMode.oneTime,
    occurrences: <EventOccurrence>[
      EventOccurrence(
        id: occurrenceId,
        startAtUtc: start.toUtc(),
        endAtUtc: end.toUtc(),
        status: EventOccurrenceStatus.scheduled,
        // E2b: Details shows the Booking panel; its terms come from Booking.
        bookingRef: EventBookingRef(
          eventId: eventId,
          occurrenceId: occurrenceId,
          channel: channel,
        ),
      ),
    ],
    displayOccurrenceId: occurrenceId,
    timezoneId: 'Europe/Riga',
    publishedAtUtc: start.toUtc(),
  );
}
