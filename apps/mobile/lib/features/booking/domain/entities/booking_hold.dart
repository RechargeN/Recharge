enum BookingHoldKind { waitlistOffer }

enum BookingHoldState { active, accepted, declined, expired, released }

class BookingHold {
  const BookingHold({
    required this.schemaVersion,
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.occurrenceId,
    required this.inventoryPoolId,
    required this.units,
    required this.kind,
    required this.state,
    required this.createdAtUtc,
    required this.expiresAtUtc,
    required this.revision,
    this.resolvedAtUtc,
  });

  final int schemaVersion;
  final String id;
  final String bookingId;
  final String userId;
  final String occurrenceId;
  final String inventoryPoolId;
  final int units;
  final BookingHoldKind kind;
  final BookingHoldState state;
  final DateTime createdAtUtc;
  final DateTime expiresAtUtc;
  final DateTime? resolvedAtUtc;
  final int revision;

  bool get isActive => state == BookingHoldState.active;
  bool get isTerminal => !isActive;
}
