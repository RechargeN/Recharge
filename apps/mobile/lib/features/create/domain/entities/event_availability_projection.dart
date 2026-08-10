import 'event_inventory.dart';

enum EventAvailabilityState {
  available,
  lowAvailability,
  soldOut,
  waitlistAvailable,
  registrationClosed,
  cancelled,
  unknown,
  stale,
}

enum AvailabilityKnowledge { known, unknown }

enum AvailabilityFreshness { current, stale, unknown }

enum AvailabilitySourceDisclosure { localMock, none }

class InventoryPoolSnapshot {
  const InventoryPoolSnapshot({
    required this.poolId,
    required this.registrationOpen,
    this.remaining,
    this.holdCount,
    this.providerStatus,
  });

  final String poolId;
  final int? remaining;
  final int? holdCount;
  final bool registrationOpen;
  final String? providerStatus;
}

class EventInventorySnapshot {
  EventInventorySnapshot({
    required this.eventId,
    required this.occurrenceId,
    required this.authority,
    required this.capturedAtUtc,
    required List<InventoryPoolSnapshot> poolStates,
    this.expiresAtUtc,
  }) : poolStates = List<InventoryPoolSnapshot>.unmodifiable(poolStates);

  final String eventId;
  final String occurrenceId;
  final InventoryAuthority authority;
  final DateTime capturedAtUtc;
  final DateTime? expiresAtUtc;
  final List<InventoryPoolSnapshot> poolStates;
}

class EventAvailabilityProjection {
  const EventAvailabilityProjection({
    required this.state,
    required this.channelStates,
    required this.knowledge,
    required this.freshness,
    required this.sourceDisclosure,
  });

  final EventAvailabilityState state;
  final Map<InventoryChannel, EventAvailabilityState> channelStates;
  final AvailabilityKnowledge knowledge;
  final AvailabilityFreshness freshness;
  final AvailabilitySourceDisclosure sourceDisclosure;

  static const EventAvailabilityProjection unknown =
      EventAvailabilityProjection(
        state: EventAvailabilityState.unknown,
        channelStates: <InventoryChannel, EventAvailabilityState>{},
        knowledge: AvailabilityKnowledge.unknown,
        freshness: AvailabilityFreshness.unknown,
        sourceDisclosure: AvailabilitySourceDisclosure.none,
      );
}
