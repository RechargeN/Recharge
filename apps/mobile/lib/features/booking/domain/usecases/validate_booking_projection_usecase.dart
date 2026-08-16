import '../entities/booking.dart';
import '../entities/booking_hold.dart';
import '../entities/booking_policy.dart';

enum BookingProjectionIssueCode {
  unsupportedSchema,
  blankId,
  invalidRevision,
  invalidParticipantUnits,
  invalidNamedGuestCount,
  poolChannelMismatch,
  waitlistRequiresFinitePool,
  activeHoldStateMismatch,
  invalidTimestamp,
  invalidStateTimestamp,
  invalidTerminalReason,
  invalidApplicationState,
  holdReferenceMismatch,
  invalidHoldState,
  unsupportedPolicy,
}

class BookingProjectionIssue {
  const BookingProjectionIssue(this.code, this.field);

  final BookingProjectionIssueCode code;
  final String field;
}

class ValidateBookingProjectionUseCase {
  const ValidateBookingProjectionUseCase();

  List<BookingProjectionIssue> call(Booking booking) {
    final issues = <BookingProjectionIssue>[];
    if (booking.schemaVersion != 1) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.unsupportedSchema,
          'schemaVersion',
        ),
      );
    }
    for (final entry in <String, String>{
      'id': booking.id,
      'userId': booking.userId,
      'eventId': booking.eventId,
      'occurrenceId': booking.occurrenceId,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        issues.add(
          BookingProjectionIssue(BookingProjectionIssueCode.blankId, entry.key),
        );
      }
    }
    if (booking.revision < 0) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidRevision,
          'revision',
        ),
      );
    }
    if (booking.participantUnits <= 0 || booking.participantUnits > 21) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidParticipantUnits,
          'participantUnits',
        ),
      );
    }
    if (booking.namedGuestCount < 0 ||
        booking.namedGuestCount >= booking.participantUnits) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidNamedGuestCount,
          'namedGuestCount',
        ),
      );
    }
    if ((booking.inventoryPoolId == null) != (booking.channel == null)) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.poolChannelMismatch,
          'inventoryPoolId',
        ),
      );
    }
    if (booking.state == BookingState.waitlisted &&
        booking.inventoryPoolId == null) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.waitlistRequiresFinitePool,
          'inventoryPoolId',
        ),
      );
    }
    if (booking.activeHoldId != null &&
        booking.state != BookingState.waitlisted) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.activeHoldStateMismatch,
          'activeHoldId',
        ),
      );
    }
    _validateTimestamps(booking, issues);
    _validateState(booking, issues);
    return List<BookingProjectionIssue>.unmodifiable(issues);
  }

  List<BookingProjectionIssue> validateHold(
    BookingHold hold, {
    Booking? booking,
  }) {
    final issues = <BookingProjectionIssue>[];
    if (hold.schemaVersion != 1) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.unsupportedSchema,
          'hold.schemaVersion',
        ),
      );
    }
    for (final entry in <String, String>{
      'hold.id': hold.id,
      'hold.bookingId': hold.bookingId,
      'hold.userId': hold.userId,
      'hold.occurrenceId': hold.occurrenceId,
      'hold.inventoryPoolId': hold.inventoryPoolId,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        issues.add(
          BookingProjectionIssue(BookingProjectionIssueCode.blankId, entry.key),
        );
      }
    }
    if (hold.revision < 0) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidRevision,
          'hold.revision',
        ),
      );
    }
    if (hold.units <= 0 || hold.units > 21) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidParticipantUnits,
          'hold.units',
        ),
      );
    }
    if (!hold.createdAtUtc.isUtc ||
        !hold.expiresAtUtc.isUtc ||
        !hold.expiresAtUtc.isAfter(hold.createdAtUtc) ||
        (hold.resolvedAtUtc != null && !hold.resolvedAtUtc!.isUtc)) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidTimestamp,
          'hold.timestamps',
        ),
      );
    }
    if ((hold.isActive && hold.resolvedAtUtc != null) ||
        (hold.isTerminal && hold.resolvedAtUtc == null)) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidHoldState,
          'hold.resolvedAtUtc',
        ),
      );
    }
    if (booking != null &&
        (hold.bookingId != booking.id ||
            hold.userId != booking.userId ||
            hold.occurrenceId != booking.occurrenceId ||
            hold.inventoryPoolId != booking.inventoryPoolId ||
            (hold.isActive && booking.activeHoldId != hold.id))) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.holdReferenceMismatch,
          'hold.booking',
        ),
      );
    }
    return List<BookingProjectionIssue>.unmodifiable(issues);
  }

  List<BookingProjectionIssue> validatePolicy(BookingPolicy policy) {
    if (policy.schemaVersion == 1 &&
        policy.policyVersion == 1 &&
        policy.maxConcurrentFiniteAllocations == 5 &&
        policy.countingRule == BookingCountingRule.onePerBookingOrActiveHold &&
        !policy.unlimitedBookingCounts) {
      return const [];
    }
    return const [
      BookingProjectionIssue(
        BookingProjectionIssueCode.unsupportedPolicy,
        'policy',
      ),
    ];
  }

  static void _validateTimestamps(
    Booking booking,
    List<BookingProjectionIssue> issues,
  ) {
    final timestamps = <DateTime?>[
      booking.createdAtUtc,
      booking.updatedAtUtc,
      booking.confirmedAtUtc,
      booking.cancelledAtUtc,
      booking.expiredAtUtc,
    ];
    if (timestamps.whereType<DateTime>().any((value) => !value.isUtc) ||
        booking.updatedAtUtc.isBefore(booking.createdAtUtc)) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidTimestamp,
          'timestamps',
        ),
      );
    }
  }

  static void _validateState(
    Booking booking,
    List<BookingProjectionIssue> issues,
  ) {
    switch (booking.state) {
      case BookingState.pending:
        if (booking.admissionMode != BookingAdmissionMode.application ||
            booking.confirmationMode !=
                BookingConfirmationMode.manualApproval) {
          issues.add(
            const BookingProjectionIssue(
              BookingProjectionIssueCode.invalidApplicationState,
              'state',
            ),
          );
        }
        break;
      case BookingState.confirmed:
        if (booking.confirmedAtUtc == null) {
          issues.add(
            const BookingProjectionIssue(
              BookingProjectionIssueCode.invalidStateTimestamp,
              'confirmedAtUtc',
            ),
          );
        }
        break;
      case BookingState.cancelled:
        if (booking.cancelledAtUtc == null) {
          issues.add(
            const BookingProjectionIssue(
              BookingProjectionIssueCode.invalidStateTimestamp,
              'cancelledAtUtc',
            ),
          );
        }
        if (booking.terminalReason == null) {
          issues.add(
            const BookingProjectionIssue(
              BookingProjectionIssueCode.invalidTerminalReason,
              'terminalReason',
            ),
          );
        }
        break;
      case BookingState.expired:
        if (booking.expiredAtUtc == null) {
          issues.add(
            const BookingProjectionIssue(
              BookingProjectionIssueCode.invalidStateTimestamp,
              'expiredAtUtc',
            ),
          );
        }
        if (booking.terminalReason == null) {
          issues.add(
            const BookingProjectionIssue(
              BookingProjectionIssueCode.invalidTerminalReason,
              'terminalReason',
            ),
          );
        }
        break;
      case BookingState.waitlisted:
        break;
    }
    if (!booking.isTerminal && booking.terminalReason != null) {
      issues.add(
        const BookingProjectionIssue(
          BookingProjectionIssueCode.invalidTerminalReason,
          'terminalReason',
        ),
      );
    }
  }
}
