import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/datasources/event_mock_inventory_datasource.dart';
import 'package:recharge/features/create/data/repositories/event_inventory_snapshot_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/event_availability_projection.dart';
import 'package:recharge/features/create/domain/entities/event_inventory.dart';
import 'package:recharge/features/create/domain/usecases/project_event_availability_usecase.dart';

void main() {
  const ProjectEventAvailabilityUseCase project =
      ProjectEventAvailabilityUseCase(lowAvailabilityThreshold: 3);
  const EventInventoryConfiguration configuration = EventInventoryConfiguration(
    authority: InventoryAuthority.recharge,
    primaryShape: InventoryShape.generalCapacity,
    pools: <EventInventoryPoolDraft>[
      EventInventoryPoolDraft(
        id: 'pool-onsite',
        label: 'Onsite',
        shape: InventoryShape.generalCapacity,
        channel: InventoryChannel.onsite,
        capacityMode: EventCapacityMode.known,
        capacity: 10,
      ),
      EventInventoryPoolDraft(
        id: 'pool-online',
        label: 'Online',
        shape: InventoryShape.generalCapacity,
        channel: InventoryChannel.online,
        capacityMode: EventCapacityMode.known,
        capacity: 100,
      ),
    ],
  );

  test('missing and expired snapshots never become available', () {
    final missing = project(
      configuration: configuration,
      snapshot: null,
      nowUtc: DateTime.utc(2030),
    );
    expect(missing.state, EventAvailabilityState.unknown);

    final stale = project(
      configuration: configuration,
      snapshot: _snapshot(expiresAtUtc: DateTime.utc(2029)),
      nowUtc: DateTime.utc(2030),
    );
    expect(stale.state, EventAvailabilityState.stale);
    expect(stale.freshness, AvailabilityFreshness.stale);
  });

  test('cancelled occurrence has highest priority', () {
    final value = project(
      configuration: configuration,
      snapshot: null,
      nowUtc: DateTime.utc(2030),
      occurrenceCancelled: true,
    );
    expect(value.state, EventAvailabilityState.cancelled);
  });

  test('hybrid channels are projected independently', () {
    final value = project(
      configuration: configuration,
      snapshot: _snapshot(),
      nowUtc: DateTime.utc(2030),
    );
    expect(
      value.channelStates[InventoryChannel.onsite],
      EventAvailabilityState.soldOut,
    );
    expect(
      value.channelStates[InventoryChannel.online],
      EventAvailabilityState.lowAvailability,
    );
    expect(value.state, EventAvailabilityState.lowAvailability);
  });

  test(
    'closed registration outranks remaining and positive stock is available',
    () {
      final closed = project(
        configuration: configuration,
        snapshot: _snapshot(
          onsiteRemaining: 10,
          onlineRemaining: 10,
          registrationOpen: false,
        ),
        nowUtc: DateTime.utc(2030),
      );
      expect(closed.state, EventAvailabilityState.registrationClosed);

      final available = project(
        configuration: configuration,
        snapshot: _snapshot(onsiteRemaining: 10, onlineRemaining: 10),
        nowUtc: DateTime.utc(2030),
      );
      expect(available.state, EventAvailabilityState.available);
    },
  );

  test('zero becomes waitlist only with verified active support', () {
    final withoutSupport = project(
      configuration: configuration,
      snapshot: _snapshot(onlineRemaining: 0),
      nowUtc: DateTime.utc(2030),
    );
    expect(withoutSupport.state, EventAvailabilityState.soldOut);

    final verified = project(
      configuration: configuration,
      snapshot: _snapshot(onlineRemaining: 0),
      nowUtc: DateTime.utc(2030),
      verifiedActiveWaitlist: true,
    );
    expect(verified.state, EventAvailabilityState.waitlistAvailable);
  });

  test('local snapshot repository is exact-id and read-only', () async {
    final EventInventorySnapshot fixture = _snapshot();
    final EventInventorySnapshotRepositoryImpl repository =
        EventInventorySnapshotRepositoryImpl(
          EventMockInventoryDataSource(
            fixtures: <EventInventorySnapshot>[fixture],
          ),
        );

    expect(
      await repository.loadSnapshot(
        eventId: fixture.eventId,
        occurrenceId: fixture.occurrenceId,
      ),
      same(fixture),
    );
    expect(
      await repository.loadSnapshot(
        eventId: fixture.eventId,
        occurrenceId: 'other',
      ),
      isNull,
    );
  });
}

EventInventorySnapshot _snapshot({
  DateTime? expiresAtUtc,
  int onsiteRemaining = 0,
  int onlineRemaining = 2,
  bool registrationOpen = true,
}) => EventInventorySnapshot(
  eventId: 'event-1',
  occurrenceId: 'occurrence-1',
  authority: InventoryAuthority.recharge,
  capturedAtUtc: DateTime.utc(2029, 12, 31),
  expiresAtUtc: expiresAtUtc ?? DateTime.utc(2031),
  poolStates: <InventoryPoolSnapshot>[
    InventoryPoolSnapshot(
      poolId: 'pool-onsite',
      remaining: onsiteRemaining,
      registrationOpen: registrationOpen,
    ),
    InventoryPoolSnapshot(
      poolId: 'pool-online',
      remaining: onlineRemaining,
      registrationOpen: registrationOpen,
    ),
  ],
);
