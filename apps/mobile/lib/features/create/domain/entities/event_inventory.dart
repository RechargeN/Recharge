enum EventCapacityMode { known, unknown, unlimited }

enum InventoryAuthority { none, recharge, externalProvider }

enum InventoryShape {
  generalCapacity,
  sharedTicketPool,
  separateTicketPools,
  zones,
  assignedSeating,
  teamSlots,
  participantRoles,
  roleBalancedSlots,
  tableInventory,
  timeSlotInventory,
}

enum InventoryChannel { onsite, online, any }

class EventInventoryPoolDraft {
  const EventInventoryPoolDraft({
    required this.id,
    required this.label,
    required this.shape,
    required this.channel,
    required this.capacityMode,
    this.capacity,
    this.roleIds = const <String>[],
    this.zoneRef,
    this.providerPoolRef,
  });

  final String id;
  final String label;
  final InventoryShape shape;
  final InventoryChannel channel;
  final EventCapacityMode capacityMode;
  final int? capacity;
  final List<String> roleIds;
  final String? zoneRef;
  final String? providerPoolRef;

  EventInventoryPoolDraft copyWith({
    String? id,
    String? label,
    InventoryShape? shape,
    InventoryChannel? channel,
    EventCapacityMode? capacityMode,
    int? capacity,
    bool clearCapacity = false,
    List<String>? roleIds,
    String? zoneRef,
    bool clearZoneRef = false,
    String? providerPoolRef,
    bool clearProviderPoolRef = false,
  }) => EventInventoryPoolDraft(
    id: id ?? this.id,
    label: label ?? this.label,
    shape: shape ?? this.shape,
    channel: channel ?? this.channel,
    capacityMode: capacityMode ?? this.capacityMode,
    capacity: clearCapacity ? null : (capacity ?? this.capacity),
    roleIds: roleIds ?? this.roleIds,
    zoneRef: clearZoneRef ? null : (zoneRef ?? this.zoneRef),
    providerPoolRef: clearProviderPoolRef
        ? null
        : (providerPoolRef ?? this.providerPoolRef),
  );
}

class EventInventoryConfiguration {
  const EventInventoryConfiguration({
    required this.authority,
    this.primaryShape,
    this.additionalShapes = const <InventoryShape>{},
    this.pools = const <EventInventoryPoolDraft>[],
  });

  final InventoryAuthority authority;
  final InventoryShape? primaryShape;
  final Set<InventoryShape> additionalShapes;
  final List<EventInventoryPoolDraft> pools;

  EventInventoryConfiguration replaceLocalIds(String Function() nextId) =>
      copyWith(
        pools: pools
            .map(
              (pool) => pool.id.startsWith('loc_')
                  ? pool.copyWith(id: nextId())
                  : pool,
            )
            .toList(growable: false),
      );

  EventInventoryConfiguration copyWith({
    InventoryAuthority? authority,
    InventoryShape? primaryShape,
    bool clearPrimaryShape = false,
    Set<InventoryShape>? additionalShapes,
    List<EventInventoryPoolDraft>? pools,
  }) => EventInventoryConfiguration(
    authority: authority ?? this.authority,
    primaryShape: clearPrimaryShape
        ? null
        : (primaryShape ?? this.primaryShape),
    additionalShapes: additionalShapes ?? this.additionalShapes,
    pools: pools ?? this.pools,
  );
}
