import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/evaluate_rental_availability_usecase.dart';

void main() {
  const EvaluateRentalAvailabilityUseCase useCase =
      EvaluateRentalAvailabilityUseCase();

  RentalInventoryGroup group({int quantity = 5}) => RentalInventoryGroup(
    id: 'g1',
    label: 'Bikes',
    quantity: quantity,
    condition: RentalCondition.good,
  );

  RentalAvailabilityBlock block({
    String id = 'b1',
    required DateTime start,
    required DateTime end,
    int unitsBlocked = 2,
    RentalBlockStatus status = RentalBlockStatus.active,
  }) => RentalAvailabilityBlock(
    id: id,
    groupId: 'g1',
    startsAtUtc: start,
    endsAtUtc: end,
    unitsBlocked: unitsBlocked,
    source: RentalBlockSource.manualExternalRental,
    status: status,
    createdByUserId: 'user-1',
    createdAtUtc: start,
    updatedAtUtc: start,
  );

  test('5 - 2 blocked = 3 declared available within fresh coverage', () {
    final DateTime confirmedAt = DateTime.utc(2026, 8, 18);
    final RentalAvailabilityCalendar calendar = RentalAvailabilityCalendar(
      timeZoneId: 'Europe/Riga',
      coverage: RentalAvailabilityCoverage(
        startsAtUtc: DateTime.utc(2026, 8, 1),
        endsAtUtc: DateTime.utc(2026, 11, 1),
        confirmedAtUtc: confirmedAt,
      ),
      blocks: <RentalAvailabilityBlock>[
        block(start: DateTime.utc(2026, 8, 12), end: DateTime.utc(2026, 8, 14)),
      ],
    );

    final RentalAvailabilityAssessment result = useCase(
      calendar: calendar,
      groups: <RentalInventoryGroup>[group()],
      queryStartUtc: DateTime.utc(2026, 8, 13),
      queryEndUtc: DateTime.utc(2026, 8, 13, 12),
      nowUtc: confirmedAt.add(const Duration(days: 1)),
    );

    expect(result.result, RentalAvailabilityResult.declaredAvailable);
    expect(result.availableUnits, 3);
  });

  test(
    'stale confirmation returns unknown, never a fabricated availability',
    () {
      final DateTime confirmedAt = DateTime.utc(2026, 7, 1);
      final RentalAvailabilityCalendar calendar = RentalAvailabilityCalendar(
        timeZoneId: 'Europe/Riga',
        coverage: RentalAvailabilityCoverage(
          startsAtUtc: DateTime.utc(2026, 7, 1),
          endsAtUtc: DateTime.utc(2026, 12, 1),
          confirmedAtUtc: confirmedAt,
        ),
      );

      final RentalAvailabilityAssessment result = useCase(
        calendar: calendar,
        groups: <RentalInventoryGroup>[group()],
        queryStartUtc: DateTime.utc(2026, 8, 13),
        queryEndUtc: DateTime.utc(2026, 8, 14),
        nowUtc: confirmedAt.add(const Duration(days: 30)),
      );

      expect(result.result, RentalAvailabilityResult.unknown);
    },
  );

  test('query outside coverage window returns unknown', () {
    final DateTime confirmedAt = DateTime.utc(2026, 8, 18);
    final RentalAvailabilityCalendar calendar = RentalAvailabilityCalendar(
      timeZoneId: 'Europe/Riga',
      coverage: RentalAvailabilityCoverage(
        startsAtUtc: DateTime.utc(2026, 8, 1),
        endsAtUtc: DateTime.utc(2026, 9, 1),
        confirmedAtUtc: confirmedAt,
      ),
    );

    final RentalAvailabilityAssessment result = useCase(
      calendar: calendar,
      groups: <RentalInventoryGroup>[group()],
      queryStartUtc: DateTime.utc(2026, 10, 1),
      queryEndUtc: DateTime.utc(2026, 10, 2),
      nowUtc: confirmedAt,
    );

    expect(result.result, RentalAvailabilityResult.unknown);
  });

  test('fully blocked group is unavailable, not unknown', () {
    final DateTime confirmedAt = DateTime.utc(2026, 8, 18);
    final RentalAvailabilityCalendar calendar = RentalAvailabilityCalendar(
      timeZoneId: 'Europe/Riga',
      coverage: RentalAvailabilityCoverage(
        startsAtUtc: DateTime.utc(2026, 8, 1),
        endsAtUtc: DateTime.utc(2026, 9, 1),
        confirmedAtUtc: confirmedAt,
      ),
      blocks: <RentalAvailabilityBlock>[
        block(
          start: DateTime.utc(2026, 8, 12),
          end: DateTime.utc(2026, 8, 14),
          unitsBlocked: 5,
        ),
      ],
    );

    final RentalAvailabilityAssessment result = useCase(
      calendar: calendar,
      groups: <RentalInventoryGroup>[group()],
      queryStartUtc: DateTime.utc(2026, 8, 13),
      queryEndUtc: DateTime.utc(2026, 8, 13, 6),
      nowUtc: confirmedAt,
    );

    expect(result.result, RentalAvailabilityResult.unavailable);
    expect(result.availableUnits, 0);
  });

  test('cancelled blocks never count toward blocked capacity', () {
    final DateTime confirmedAt = DateTime.utc(2026, 8, 18);
    final RentalAvailabilityCalendar calendar = RentalAvailabilityCalendar(
      timeZoneId: 'Europe/Riga',
      coverage: RentalAvailabilityCoverage(
        startsAtUtc: DateTime.utc(2026, 8, 1),
        endsAtUtc: DateTime.utc(2026, 9, 1),
        confirmedAtUtc: confirmedAt,
      ),
      blocks: <RentalAvailabilityBlock>[
        block(
          start: DateTime.utc(2026, 8, 12),
          end: DateTime.utc(2026, 8, 14),
          unitsBlocked: 5,
          status: RentalBlockStatus.cancelled,
        ),
      ],
    );

    final RentalAvailabilityAssessment result = useCase(
      calendar: calendar,
      groups: <RentalInventoryGroup>[group()],
      queryStartUtc: DateTime.utc(2026, 8, 13),
      queryEndUtc: DateTime.utc(2026, 8, 13, 6),
      nowUtc: confirmedAt,
    );

    expect(result.result, RentalAvailabilityResult.declaredAvailable);
    expect(result.availableUnits, 5);
  });

  test('wouldExceedCapacity rejects a block that overshoots quantity', () {
    final RentalInventoryGroup g = group(quantity: 3);
    final RentalAvailabilityBlock existing = block(
      id: 'existing',
      start: DateTime.utc(2026, 8, 12),
      end: DateTime.utc(2026, 8, 14),
      unitsBlocked: 2,
    );
    final RentalAvailabilityBlock candidate = block(
      id: 'candidate',
      start: DateTime.utc(2026, 8, 13),
      end: DateTime.utc(2026, 8, 15),
      unitsBlocked: 2,
    );

    final bool exceeds = useCase.wouldExceedCapacity(
      group: g,
      existingActiveBlocksForGroup: <RentalAvailabilityBlock>[existing],
      candidate: candidate,
    );

    expect(exceeds, isTrue);
  });

  test('wouldExceedCapacity accepts a block within remaining capacity', () {
    final RentalInventoryGroup g = group(quantity: 5);
    final RentalAvailabilityBlock existing = block(
      id: 'existing',
      start: DateTime.utc(2026, 8, 12),
      end: DateTime.utc(2026, 8, 14),
      unitsBlocked: 2,
    );
    final RentalAvailabilityBlock candidate = block(
      id: 'candidate',
      start: DateTime.utc(2026, 8, 13),
      end: DateTime.utc(2026, 8, 15),
      unitsBlocked: 2,
    );

    final bool exceeds = useCase.wouldExceedCapacity(
      group: g,
      existingActiveBlocksForGroup: <RentalAvailabilityBlock>[existing],
      candidate: candidate,
    );

    expect(exceeds, isFalse);
  });
}
