import '../entities/event_availability_projection.dart';
import '../entities/event_inventory.dart';

class ProjectEventAvailabilityUseCase {
  const ProjectEventAvailabilityUseCase({this.lowAvailabilityThreshold = 3});

  final int lowAvailabilityThreshold;

  EventAvailabilityProjection call({
    required EventInventoryConfiguration configuration,
    required EventInventorySnapshot? snapshot,
    required DateTime nowUtc,
    bool occurrenceCancelled = false,
    bool verifiedActiveWaitlist = false,
  }) {
    if (occurrenceCancelled) {
      return const EventAvailabilityProjection(
        state: EventAvailabilityState.cancelled,
        channelStates: <InventoryChannel, EventAvailabilityState>{},
        knowledge: AvailabilityKnowledge.known,
        freshness: AvailabilityFreshness.current,
        sourceDisclosure: AvailabilitySourceDisclosure.none,
      );
    }
    if (snapshot == null ||
        snapshot.eventId.trim().isEmpty ||
        snapshot.occurrenceId.trim().isEmpty ||
        snapshot.authority != configuration.authority) {
      return EventAvailabilityProjection.unknown;
    }
    if (snapshot.expiresAtUtc != null &&
        !snapshot.expiresAtUtc!.isAfter(nowUtc)) {
      return const EventAvailabilityProjection(
        state: EventAvailabilityState.stale,
        channelStates: <InventoryChannel, EventAvailabilityState>{},
        knowledge: AvailabilityKnowledge.unknown,
        freshness: AvailabilityFreshness.stale,
        sourceDisclosure: AvailabilitySourceDisclosure.localMock,
      );
    }

    final Map<String, InventoryPoolSnapshot> states =
        <String, InventoryPoolSnapshot>{
          for (final InventoryPoolSnapshot state in snapshot.poolStates)
            state.poolId: state,
        };
    final Map<InventoryChannel, EventAvailabilityState> channels =
        <InventoryChannel, EventAvailabilityState>{};
    for (final InventoryChannel channel in const <InventoryChannel>[
      InventoryChannel.onsite,
      InventoryChannel.online,
    ]) {
      final List<EventInventoryPoolDraft> pools = configuration.pools
          .where(
            (pool) =>
                pool.channel == channel || pool.channel == InventoryChannel.any,
          )
          .toList(growable: false);
      if (pools.isNotEmpty) {
        channels[channel] = _projectPools(
          pools,
          states,
          verifiedActiveWaitlist: verifiedActiveWaitlist,
        );
      }
    }
    if (channels.isEmpty && configuration.pools.isNotEmpty) {
      channels[InventoryChannel.any] = _projectPools(
        configuration.pools,
        states,
        verifiedActiveWaitlist: verifiedActiveWaitlist,
      );
    }
    final EventAvailabilityState overall = _combine(channels.values);
    return EventAvailabilityProjection(
      state: overall,
      channelStates: Map<InventoryChannel, EventAvailabilityState>.unmodifiable(
        channels,
      ),
      knowledge: _known(overall)
          ? AvailabilityKnowledge.known
          : AvailabilityKnowledge.unknown,
      freshness: AvailabilityFreshness.current,
      sourceDisclosure: AvailabilitySourceDisclosure.localMock,
    );
  }

  EventAvailabilityState _projectPools(
    List<EventInventoryPoolDraft> pools,
    Map<String, InventoryPoolSnapshot> states, {
    required bool verifiedActiveWaitlist,
  }) {
    int remaining = 0;
    bool hasKnownRemaining = false;
    bool hasOpenRegistration = false;
    for (final EventInventoryPoolDraft pool in pools) {
      final InventoryPoolSnapshot? state = states[pool.id];
      if (state == null || state.remaining == null || state.remaining! < 0) {
        return EventAvailabilityState.unknown;
      }
      if (!state.registrationOpen) continue;
      hasOpenRegistration = true;
      hasKnownRemaining = true;
      remaining += state.remaining!;
    }
    if (!hasOpenRegistration) {
      return EventAvailabilityState.registrationClosed;
    }
    if (!hasKnownRemaining) return EventAvailabilityState.unknown;
    if (remaining == 0) {
      return verifiedActiveWaitlist
          ? EventAvailabilityState.waitlistAvailable
          : EventAvailabilityState.soldOut;
    }
    return remaining <= lowAvailabilityThreshold
        ? EventAvailabilityState.lowAvailability
        : EventAvailabilityState.available;
  }

  EventAvailabilityState _combine(Iterable<EventAvailabilityState> states) {
    final List<EventAvailabilityState> values = states.toList(growable: false);
    if (values.isEmpty || values.contains(EventAvailabilityState.unknown)) {
      return EventAvailabilityState.unknown;
    }
    if (values.contains(EventAvailabilityState.available)) {
      return EventAvailabilityState.available;
    }
    if (values.contains(EventAvailabilityState.lowAvailability)) {
      return EventAvailabilityState.lowAvailability;
    }
    if (values.contains(EventAvailabilityState.waitlistAvailable)) {
      return EventAvailabilityState.waitlistAvailable;
    }
    if (values.every(
      (value) => value == EventAvailabilityState.registrationClosed,
    )) {
      return EventAvailabilityState.registrationClosed;
    }
    return EventAvailabilityState.soldOut;
  }

  bool _known(EventAvailabilityState state) =>
      state != EventAvailabilityState.unknown &&
      state != EventAvailabilityState.stale;
}
