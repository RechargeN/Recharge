import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/domain/entities/booking.dart';
import 'package:recharge/features/booking/domain/entities/booking_hold.dart';
import 'package:recharge/features/booking/domain/entities/booking_policy.dart';
import 'package:recharge/features/booking/domain/usecases/validate_booking_projection_usecase.dart';

void main() {
  const validate = ValidateBookingProjectionUseCase();

  test('valid confirmed finite Booking passes pure projection validation', () {
    expect(validate(_booking()), isEmpty);
  });

  test('invalid authority projection fails without normalization', () {
    final invalid = _booking(
      state: BookingState.waitlisted,
      participantUnits: 0,
      namedGuestCount: 2,
      inventoryPoolId: null,
      channel: null,
      activeHoldId: 'hold-1',
      confirmedAtUtc: null,
    );

    final issues = validate(invalid).map((issue) => issue.code).toSet();
    expect(
      issues,
      containsAll(<BookingProjectionIssueCode>{
        BookingProjectionIssueCode.invalidParticipantUnits,
        BookingProjectionIssueCode.invalidNamedGuestCount,
        BookingProjectionIssueCode.waitlistRequiresFinitePool,
      }),
    );
    expect(invalid.participantUnits, 0);
    expect(invalid.inventoryPoolId, isNull);
  });

  test('active hold must match Booking, user, occurrence and pool', () {
    final booking = _booking(
      state: BookingState.waitlisted,
      activeHoldId: 'hold-1',
      confirmedAtUtc: null,
    );
    final hold = _hold();
    expect(validate.validateHold(hold, booking: booking), isEmpty);

    final mismatched = _hold(bookingId: 'other-booking');
    expect(
      validate
          .validateHold(mismatched, booking: booking)
          .map((issue) => issue.code),
      contains(BookingProjectionIssueCode.holdReferenceMismatch),
    );
  });

  test('resolved hold and policy values are fail-closed', () {
    expect(
      validate.validateHold(
        _hold(state: BookingHoldState.expired, resolvedAtUtc: null),
      ),
      isNotEmpty,
    );
    expect(validate.validatePolicy(BookingPolicy.v1), isEmpty);
    expect(
      validate.validatePolicy(
        const BookingPolicy(
          schemaVersion: 1,
          policyVersion: 1,
          maxConcurrentFiniteAllocations: 6,
          countingRule: BookingCountingRule.onePerBookingOrActiveHold,
          unlimitedBookingCounts: false,
        ),
      ),
      isNotEmpty,
    );
  });
}

Booking _booking({
  BookingState state = BookingState.confirmed,
  int participantUnits = 2,
  int namedGuestCount = 1,
  String? inventoryPoolId = 'pool-1',
  BookingChannel? channel = BookingChannel.onsite,
  String? activeHoldId,
  DateTime? confirmedAtUtc,
}) {
  final created = DateTime.utc(2026, 8, 9, 8);
  return Booking(
    schemaVersion: 1,
    id: 'booking-1',
    revision: 2,
    userId: 'user-1',
    eventId: 'event-1',
    occurrenceId: 'occurrence-1',
    inventoryPoolId: inventoryPoolId,
    channel: channel,
    admissionMode: BookingAdmissionMode.booking,
    confirmationMode: BookingConfirmationMode.instant,
    state: state,
    participantUnits: participantUnits,
    namedGuestCount: namedGuestCount,
    activeHoldId: activeHoldId,
    reconfirmationState: BookingReconfirmationState.notRequired,
    createdAtUtc: created,
    updatedAtUtc: created.add(const Duration(minutes: 1)),
    confirmedAtUtc:
        confirmedAtUtc ??
        (state == BookingState.confirmed
            ? created.add(const Duration(minutes: 1))
            : null),
  );
}

BookingHold _hold({
  String bookingId = 'booking-1',
  BookingHoldState state = BookingHoldState.active,
  DateTime? resolvedAtUtc,
}) {
  return BookingHold(
    schemaVersion: 1,
    id: 'hold-1',
    bookingId: bookingId,
    userId: 'user-1',
    occurrenceId: 'occurrence-1',
    inventoryPoolId: 'pool-1',
    units: 2,
    kind: BookingHoldKind.waitlistOffer,
    state: state,
    createdAtUtc: DateTime.utc(2026, 8, 9, 9),
    expiresAtUtc: DateTime.utc(2026, 8, 9, 10),
    resolvedAtUtc: resolvedAtUtc,
    revision: state == BookingHoldState.active ? 0 : 1,
  );
}
