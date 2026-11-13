import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';

void main() {
  test('defaults produce a valid, empty draft owned by the given user', () {
    final RentalDraftData draft = RentalDraftData.defaults(
      userId: 'user-1',
      currencyCode: 'EUR',
      timeZoneId: 'Europe/Riga',
    );

    expect(draft.publisherRef.id, 'user-1');
    expect(draft.inventoryGroups, isEmpty);
    expect(draft.totalUnitsAggregate, 0);
    expect(draft.pricing.deposit.isZero, isTrue);
  });

  test('nextRevision increments revision without touching other fields', () {
    final RentalDraftData draft = RentalDraftData.defaults(
      userId: 'user-1',
      currencyCode: 'EUR',
      timeZoneId: 'Europe/Riga',
    );
    final RentalDraftData next = draft.copyWith(title: 'Kayaks').nextRevision();

    expect(next.revision, 1);
    expect(next.title, 'Kayaks');
  });

  test('totalUnitsAggregate only counts available groups', () {
    final RentalDraftData draft =
        RentalDraftData.defaults(
          userId: 'user-1',
          currencyCode: 'EUR',
          timeZoneId: 'Europe/Riga',
        ).copyWith(
          inventoryGroups: const <RentalInventoryGroup>[
            RentalInventoryGroup(
              id: 'g1',
              label: 'A',
              quantity: 5,
              condition: RentalCondition.good,
            ),
            RentalInventoryGroup(
              id: 'g2',
              label: 'B',
              quantity: 3,
              condition: RentalCondition.good,
              status: RentalUnitGroupStatus.paused,
            ),
          ],
        );

    expect(draft.totalUnitsAggregate, 5);
  });

  test('replaceLocalIds renews only loc_ prefixed group and block ids', () {
    final RentalDraftData draft =
        RentalDraftData.defaults(
          userId: 'user-1',
          currencyCode: 'EUR',
          timeZoneId: 'Europe/Riga',
        ).copyWith(
          inventoryGroups: const <RentalInventoryGroup>[
            RentalInventoryGroup(
              id: 'loc_group',
              label: 'A',
              quantity: 5,
              condition: RentalCondition.good,
            ),
            RentalInventoryGroup(
              id: 'permanent_group',
              label: 'B',
              quantity: 2,
              condition: RentalCondition.good,
            ),
          ],
          availability: RentalAvailabilityCalendar(
            timeZoneId: 'Europe/Riga',
            blocks: <RentalAvailabilityBlock>[
              RentalAvailabilityBlock(
                id: 'loc_block',
                groupId: 'loc_group',
                startsAtUtc: DateTime.utc(2026, 8, 1),
                endsAtUtc: DateTime.utc(2026, 8, 2),
                unitsBlocked: 1,
                source: RentalBlockSource.manualExternalRental,
                createdByUserId: 'user-1',
                createdAtUtc: DateTime.utc(2026, 8, 1),
                updatedAtUtc: DateTime.utc(2026, 8, 1),
              ),
            ],
          ),
        );

    int counter = 0;
    final RentalDraftData renewed = draft.replaceLocalIds(
      () => 'permanent_${counter++}',
    );

    final String renewedGroupId = renewed.inventoryGroups
        .firstWhere((RentalInventoryGroup g) => g.label == 'A')
        .id;
    expect(renewedGroupId, isNot(startsWith('loc_')));
    expect(
      renewed.inventoryGroups
          .firstWhere((RentalInventoryGroup g) => g.label == 'B')
          .id,
      'permanent_group',
    );
    expect(renewed.availability.blocks.single.id, isNot(startsWith('loc_')));
    expect(renewed.availability.blocks.single.groupId, renewedGroupId);
  });
}
