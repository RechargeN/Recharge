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
    priceAmount: 0,
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
