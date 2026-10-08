/// Client view of one Booking. Authority stays on the server: this is only what
/// the server last confirmed to this device.
enum EventBookingState { pending, confirmed, cancelled, expired, waitlisted }

final class EventBookingView {
  const EventBookingView({
    required this.id,
    required this.occurrenceId,
    required this.state,
    required this.participantUnits,
    required this.revision,
  });

  final String id;
  final String occurrenceId;
  final EventBookingState state;
  final int participantUnits;
  final int revision;

  bool get isActive =>
      state == EventBookingState.pending ||
      state == EventBookingState.confirmed ||
      state == EventBookingState.waitlisted;
}

enum EventBookingOperationKind { create, cancel }

/// A user intent that survives restarts. The idempotency key is created and
/// persisted before the first dispatch, so every retry, replay and recovery of
/// the same intent reuses it and the server can never create a second Booking.
final class EventBookingOperation {
  const EventBookingOperation({
    required this.kind,
    required this.idempotencyKey,
    required this.occurrenceId,
    this.inventoryPoolId,
    this.channel,
    this.participantUnits,
    this.eventRevision,
    this.bookingId,
    this.expectedBookingRevision,
  });

  factory EventBookingOperation.fromJson(Map<String, Object?> json) =>
      EventBookingOperation(
        kind: EventBookingOperationKind.values.byName(json['kind']! as String),
        idempotencyKey: json['idempotencyKey']! as String,
        occurrenceId: json['occurrenceId']! as String,
        inventoryPoolId: json['inventoryPoolId'] as String?,
        channel: json['channel'] as String?,
        participantUnits: json['participantUnits'] as int?,
        eventRevision: json['eventRevision'] as int?,
        bookingId: json['bookingId'] as String?,
        expectedBookingRevision: json['expectedBookingRevision'] as int?,
      );

  final EventBookingOperationKind kind;
  final String idempotencyKey;
  final String occurrenceId;
  final String? inventoryPoolId;
  final String? channel;
  final int? participantUnits;
  final int? eventRevision;
  final String? bookingId;
  final int? expectedBookingRevision;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'idempotencyKey': idempotencyKey,
    'occurrenceId': occurrenceId,
    if (inventoryPoolId != null) 'inventoryPoolId': inventoryPoolId,
    if (channel != null) 'channel': channel,
    if (participantUnits != null) 'participantUnits': participantUnits,
    if (eventRevision != null) 'eventRevision': eventRevision,
    if (bookingId != null) 'bookingId': bookingId,
    if (expectedBookingRevision != null)
      'expectedBookingRevision': expectedBookingRevision,
  };
}

enum EventBookingOutcome {
  /// The server confirmed the result. [EventBookingResult.booking] is the
  /// resulting Booking, or null when the user has no active Booking.
  succeeded,

  /// The command may have reached the server but the answer was lost.
  unknownOutcome,

  /// The command was not sent (no connection); retrying is safe.
  offline,
  unauthenticated,
  rejected,
}

final class EventBookingResult {
  const EventBookingResult(this.outcome, {this.booking});

  final EventBookingOutcome outcome;
  final EventBookingView? booking;
}

/// E2.0: the booking terms of one exact occurrence, as Booking holds them.
final class EventBookingTerms {
  const EventBookingTerms({
    required this.eventId,
    required this.occurrenceId,
    required this.eventRevision,
    required this.status,
    required this.maxParticipantUnits,
    this.inventoryPoolId,
    this.channel,
    this.cancellationDeadline,
  });

  final String eventId;
  final String occurrenceId;
  final int eventRevision;

  /// Booking's own status: available, limited, soldOut, notOpen or closed.
  final String status;
  final int maxParticipantUnits;
  final String? inventoryPoolId;
  final String? channel;
  final DateTime? cancellationDeadline;

  bool get open => status == 'available' || status == 'limited';
}

enum EventBookingTermsOutcome {
  succeeded,

  /// Booking refused: not bookable (for example hidden, cancelled or absent).
  unavailable,
  offline,
  unknownOutcome,
  unauthenticated,
}

final class EventBookingTermsResult {
  const EventBookingTermsResult(this.outcome, {this.terms, this.code});

  final EventBookingTermsOutcome outcome;
  final EventBookingTerms? terms;
  final String? code;
}

abstract interface class EventBookingGateway {
  /// The user's active Booking for [occurrenceId], read from the server.
  Future<EventBookingResult> activeFor(String occurrenceId);

  /// Booking terms and status of one exact occurrence, read from Booking.
  Future<EventBookingTermsResult> termsFor({
    required String eventId,
    required String occurrenceId,
    String? channel,
  });

  /// Sends (or replays) [operation]; replay with the same key is idempotent.
  Future<EventBookingResult> execute(EventBookingOperation operation);
}

abstract interface class EventBookingOperationStore {
  Future<EventBookingOperation?> read(String occurrenceId);
  Future<void> write(EventBookingOperation operation);
  Future<void> clear(String occurrenceId);
}
