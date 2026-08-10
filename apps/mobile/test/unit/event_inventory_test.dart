import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/event_inventory.dart';
import 'package:recharge/features/create/domain/usecases/validate_event_access_configuration_usecase.dart';

void main() {
  const ValidateEventAccessConfigurationUseCase validate =
      ValidateEventAccessConfigurationUseCase();

  test('canonical inventory dictionaries are complete and independent', () {
    expect(InventoryAuthority.values, hasLength(3));
    expect(InventoryShape.values, hasLength(10));
    expect(InventoryChannel.values, hasLength(3));
    expect(
      InventoryShape.values.map((value) => value.name),
      isNot(contains(InventoryAuthority.recharge.name)),
    );
  });

  test('finite hybrid requires a bounded onsite pool; any is insufficient', () {
    final issues = validate(
      admission: null,
      inventory: const EventInventoryConfiguration(
        authority: InventoryAuthority.none,
        pools: <EventInventoryPoolDraft>[
          EventInventoryPoolDraft(
            id: 'loc_any',
            label: 'Shared',
            shape: InventoryShape.generalCapacity,
            channel: InventoryChannel.any,
            capacityMode: EventCapacityMode.known,
            capacity: 20,
          ),
        ],
      ),
      capacityMode: EventCapacityMode.known,
      capacity: 20,
      format: EventFormat.hybrid,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: const <EventOccurrenceDraft>[],
      externalRegistrationUrl: null,
    );

    expect(
      issues.map((issue) => issue.code),
      contains('hybrid_onsite_pool_required'),
    );
  });

  test('known pool totals are counted once by stable ID and channel', () {
    final issues = validate(
      admission: null,
      inventory: const EventInventoryConfiguration(
        authority: InventoryAuthority.recharge,
        primaryShape: InventoryShape.sharedTicketPool,
        additionalShapes: <InventoryShape>{InventoryShape.zones},
        pools: <EventInventoryPoolDraft>[
          EventInventoryPoolDraft(
            id: 'loc_pool_a',
            label: 'Main',
            shape: InventoryShape.sharedTicketPool,
            channel: InventoryChannel.onsite,
            capacityMode: EventCapacityMode.known,
            capacity: 21,
          ),
        ],
      ),
      capacityMode: EventCapacityMode.known,
      capacity: 20,
      format: EventFormat.offline,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: const <EventOccurrenceDraft>[],
      externalRegistrationUrl: null,
    );

    expect(
      issues.map((issue) => issue.code),
      contains('inventory_pool_total_exceeds_event_capacity'),
    );
    expect(
      issues
          .where(
            (issue) =>
                issue.code == 'inventory_pool_total_exceeds_event_capacity',
          )
          .length,
      1,
    );
  });

  test('assigned seating and external authority remain gated', () {
    final issues = validate(
      admission: null,
      inventory: const EventInventoryConfiguration(
        authority: InventoryAuthority.externalProvider,
        primaryShape: InventoryShape.assignedSeating,
        pools: <EventInventoryPoolDraft>[
          EventInventoryPoolDraft(
            id: 'loc_seats',
            label: 'Seats',
            shape: InventoryShape.assignedSeating,
            channel: InventoryChannel.onsite,
            capacityMode: EventCapacityMode.unknown,
          ),
        ],
      ),
      capacityMode: EventCapacityMode.unknown,
      capacity: null,
      format: EventFormat.offline,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: const <EventOccurrenceDraft>[],
      externalRegistrationUrl: null,
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll(<String>[
        'assigned_seating_not_ready',
        'external_inventory_not_ready',
      ]),
    );
  });

  test('any-channel pool consumes both channel budgets without double IDs', () {
    final issues = validate(
      admission: null,
      inventory: const EventInventoryConfiguration(
        authority: InventoryAuthority.recharge,
        primaryShape: InventoryShape.generalCapacity,
        pools: <EventInventoryPoolDraft>[
          EventInventoryPoolDraft(
            id: 'loc_onsite',
            label: 'Onsite',
            shape: InventoryShape.generalCapacity,
            channel: InventoryChannel.onsite,
            capacityMode: EventCapacityMode.known,
            capacity: 10,
          ),
          EventInventoryPoolDraft(
            id: 'loc_any',
            label: 'Shared',
            shape: InventoryShape.generalCapacity,
            channel: InventoryChannel.any,
            capacityMode: EventCapacityMode.known,
            capacity: 15,
          ),
        ],
      ),
      capacityMode: EventCapacityMode.known,
      capacity: 20,
      format: EventFormat.hybrid,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: const <EventOccurrenceDraft>[],
      externalRegistrationUrl: null,
    );

    expect(
      issues.map((issue) => issue.code),
      contains('inventory_pool_total_exceeds_event_capacity'),
    );
  });
}
