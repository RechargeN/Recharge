import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/repositories/event_booking_gateway.dart';

enum EventBookingPhase {
  loading,
  ready,
  submitting,

  /// The command may have reached the server; the same intent is replayed
  /// with the same idempotency key, never as a new command.
  unknownOutcome,
  offline,
  error,
}

final class EventBookingViewState {
  const EventBookingViewState({
    required this.phase,
    this.booking,
    this.hasPendingOperation = false,
    this.message,
    this.seats = 1,
    this.maxSeats = 1,
  });

  final EventBookingPhase phase;

  /// The user's active Booking for this occurrence, as last confirmed by the
  /// server.
  final EventBookingView? booking;
  final bool hasPendingOperation;
  final String? message;

  /// F2: the number of seats chosen for a new Booking, within Booking terms.
  final int seats;
  final int maxSeats;

  bool get canBook =>
      phase == EventBookingPhase.ready &&
      (booking == null || !booking!.isActive) &&
      !hasPendingOperation;
  bool get canCancel =>
      phase == EventBookingPhase.ready &&
      booking != null &&
      booking!.isActive &&
      !hasPendingOperation;

  /// F2: only an active Booking that Booking asks to reconfirm.
  bool get canReconfirm =>
      phase == EventBookingPhase.ready &&
      booking != null &&
      booking!.reconfirmationRequired &&
      !hasPendingOperation;
  bool get canRetry =>
      phase == EventBookingPhase.unknownOutcome ||
      phase == EventBookingPhase.offline ||
      phase == EventBookingPhase.error;

  /// F2: re-read the server explicitly (there is no push).
  bool get canRefresh =>
      phase == EventBookingPhase.ready || phase == EventBookingPhase.error;

  EventBookingViewState copyWith({int? seats}) => EventBookingViewState(
    phase: phase,
    booking: booking,
    hasPendingOperation: hasPendingOperation,
    message: message,
    seats: seats ?? this.seats,
    maxSeats: maxSeats,
  );
}

/// Client coordinator for one Event occurrence. It owns no authority: every
/// state shown is a server answer, and every command is journaled first.
final class EventBookingController extends ChangeNotifier {
  EventBookingController({
    required EventBookingGateway gateway,
    required EventBookingOperationStore store,
    required this.occurrenceId,
    required this.inventoryPoolId,
    required this.channel,
    required this.eventRevision,
    int maxParticipantUnits = 1,
    Uuid uuid = const Uuid(),
  }) : _gateway = gateway,
       _store = store,
       _uuid = uuid,
       maxParticipantUnits = maxParticipantUnits < 1 ? 1 : maxParticipantUnits;

  final EventBookingGateway _gateway;
  final EventBookingOperationStore _store;
  final Uuid _uuid;
  final String occurrenceId;

  /// Server-generated pool and channel from Booking terms; both absent for
  /// unlimited capacity.
  final String? inventoryPoolId;
  final String? channel;
  final int eventRevision;

  /// F2: the party limit from Booking terms; the UI never offers more.
  final int maxParticipantUnits;

  late EventBookingViewState _state = EventBookingViewState(
    phase: EventBookingPhase.loading,
    maxSeats: maxParticipantUnits,
  );
  bool _busy = false;
  bool _disposed = false;

  /// The last Booking this screen showed, to explain why it ended.
  String? _lastBookingId;

  EventBookingViewState get state => _state;

  void _emit(EventBookingViewState next) {
    _state = next;
    final String? id = next.booking?.id;
    if (id != null) _lastBookingId = id;
    if (!_disposed) notifyListeners();
  }

  EventBookingViewState _next(
    EventBookingPhase phase, {
    EventBookingView? booking,
    bool hasPendingOperation = false,
    String? message,
  }) => EventBookingViewState(
    phase: phase,
    booking: booking,
    hasPendingOperation: hasPendingOperation,
    message: message,
    seats: _state.seats,
    maxSeats: maxParticipantUnits,
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Opens the screen: replays a journaled intent first (restart recovery),
  /// otherwise reads the server state.
  Future<void> load() => _guarded(() async {
    _emit(_next(EventBookingPhase.loading, booking: _state.booking));
    final pending = await _store.read(occurrenceId);
    if (pending != null) {
      await _run(pending);
    } else {
      await _refresh();
    }
  });

  /// F2: chooses the number of seats for a new Booking, 1..[maxParticipantUnits].
  void selectSeats(int seats) {
    final int bounded = seats < 1
        ? 1
        : (seats > maxParticipantUnits ? maxParticipantUnits : seats);
    if (bounded == _state.seats) return;
    _emit(_state.copyWith(seats: bounded));
  }

  Future<void> book() => _guarded(() async {
    // Re-entrancy guard: a double tap is one intent, not two commands.
    if (!_state.canBook) return;
    var operation = await _store.read(occurrenceId);
    operation ??= EventBookingOperation(
      kind: EventBookingOperationKind.create,
      idempotencyKey: _uuid.v4(),
      occurrenceId: occurrenceId,
      inventoryPoolId: inventoryPoolId,
      channel: channel,
      participantUnits: _state.seats,
      eventRevision: eventRevision,
    );
    // The intent is durable before the first dispatch.
    await _store.write(operation);
    await _run(operation);
  });

  Future<void> cancel() => _guarded(() async {
    final booking = _state.booking;
    if (!_state.canCancel || booking == null) return;
    final operation = EventBookingOperation(
      kind: EventBookingOperationKind.cancel,
      idempotencyKey: _uuid.v4(),
      occurrenceId: occurrenceId,
      bookingId: booking.id,
      expectedBookingRevision: booking.revision,
    );
    await _store.write(operation);
    await _run(operation);
  });

  /// F2: confirms attendance for the exact material revision Booking named.
  /// Journaled like create/cancel, so a lost answer, offline or a restart
  /// replays the same intent and never confirms twice.
  Future<void> reconfirm() => _guarded(() async {
    final booking = _state.booking;
    final int? materialRevision = booking?.reconfirmationRequiredForRevision;
    if (!_state.canReconfirm || booking == null || materialRevision == null) {
      return;
    }
    final operation = EventBookingOperation(
      kind: EventBookingOperationKind.reconfirm,
      idempotencyKey: _uuid.v4(),
      occurrenceId: occurrenceId,
      bookingId: booking.id,
      expectedBookingRevision: booking.revision,
      materialRevision: materialRevision,
    );
    await _store.write(operation);
    await _run(operation);
  });

  /// Replays the journaled intent with its original idempotency key, or
  /// re-reads the server when nothing is pending.
  Future<void> retry() => _guarded(() async {
    final pending = await _store.read(occurrenceId);
    if (pending != null) {
      await _run(pending);
    } else {
      await _refresh();
    }
  });

  /// F2: explicit re-read of the server state (no push): a reschedule, an
  /// occurrence cancellation or a missed deadline shows up here.
  Future<void> refresh() => retry();

  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }

  Future<void> _refresh({String? message}) async {
    final result = await _gateway.activeFor(occurrenceId);
    switch (result.outcome) {
      case EventBookingOutcome.succeeded:
        final EventBookingView? active = result.booking;
        _emit(
          _next(
            EventBookingPhase.ready,
            booking: active,
            message: message ?? (active == null ? await _endedReason() : null),
          ),
        );
      case EventBookingOutcome.offline:
      case EventBookingOutcome.unknownOutcome:
      case EventBookingOutcome.rateLimited:
        _emit(
          _next(
            EventBookingPhase.offline,
            booking: _state.booking,
            message: 'No connection. Try again when you are back online.',
          ),
        );
      case EventBookingOutcome.unauthenticated:
        _emit(
          _next(
            EventBookingPhase.error,
            message: 'Your session could not be confirmed. Try again.',
          ),
        );
      case EventBookingOutcome.rejected:
        _emit(
          _next(
            EventBookingPhase.error,
            message: 'Booking could not be loaded.',
          ),
        );
    }
  }

  /// Why the Booking this screen last showed is no longer active, when it
  /// was ended by someone else or by a deadline; null when the user ended it
  /// or nothing was shown.
  Future<String?> _endedReason() async {
    final String? id = _lastBookingId;
    if (id == null) return null;
    final EventBookingResult ended = await _gateway.booking(id);
    final EventBookingView? booking = ended.booking;
    if (ended.outcome != EventBookingOutcome.succeeded || booking == null) {
      return null;
    }
    return switch (booking.terminalReason) {
      'missedReconfirmation' =>
        'Your booking was released because attendance was not confirmed in '
            'time.',
      'occurrenceCancelled' || 'eventCancelled' =>
        'The organizer cancelled this event; your booking was cancelled.',
      'organizerCancelled' => 'The organizer cancelled your booking.',
      _ => null,
    };
  }

  Future<void> _run(EventBookingOperation operation) async {
    _emit(
      _next(
        EventBookingPhase.submitting,
        booking: _state.booking,
        hasPendingOperation: true,
      ),
    );
    final result = await _gateway.execute(operation);
    switch (result.outcome) {
      case EventBookingOutcome.succeeded:
        await _store.clear(occurrenceId);
        // The server answer is only a confirmation; the visible Booking is
        // always re-read from the server.
        await _refresh();
      case EventBookingOutcome.unknownOutcome:
        _emit(
          _next(
            EventBookingPhase.unknownOutcome,
            booking: _state.booking,
            hasPendingOperation: true,
            message:
                'We could not confirm the result. Checking again will not '
                'create a second booking.',
          ),
        );
      case EventBookingOutcome.offline:
        _emit(
          _next(
            EventBookingPhase.offline,
            booking: _state.booking,
            hasPendingOperation: true,
            message:
                'No connection. Your request is saved and will not be '
                'duplicated.',
          ),
        );
      case EventBookingOutcome.rateLimited:
        // Refused before execution: the saved intent is sent again later with
        // the same key.
        final int? seconds = result.retryAfter?.inSeconds;
        _emit(
          _next(
            EventBookingPhase.offline,
            booking: _state.booking,
            hasPendingOperation: true,
            message: seconds == null
                ? 'Too many attempts. Try again shortly.'
                : 'Too many attempts. Try again in $seconds s.',
          ),
        );
      case EventBookingOutcome.unauthenticated:
        _emit(
          _next(
            EventBookingPhase.error,
            booking: _state.booking,
            hasPendingOperation: true,
            message: 'Your session could not be confirmed. Try again.',
          ),
        );
      case EventBookingOutcome.rejected:
        // A final server refusal ends the intent; the user may start over.
        await _store.clear(occurrenceId);
        _emit(
          _next(
            EventBookingPhase.error,
            booking: _state.booking,
            message: refusalMessage(result.refusalCode),
          ),
        );
    }
  }

  /// F2: Booking's typed refusal as a user message; an unknown code keeps the
  /// general wording.
  static String refusalMessage(String? code) => switch (code) {
    'sold_out' => 'This event is sold out.',
    'active_booking_limit_reached' || 'concurrency_cap_reached' =>
      'You have reached the limit of active bookings.',
    'registration_not_open' => 'Registration has not opened yet.',
    'registration_closed' => 'Registration is closed.',
    'cancellation_deadline_passed' => 'The cancellation deadline has passed.',
    'reconfirmation_deadline_passed' => 'The confirmation deadline has passed.',
    'material_revision_mismatch' =>
      'The event changed again. Refresh and confirm the new time.',
    'reconfirmation_not_required' => 'No confirmation is needed now.',
    'revision_conflict' =>
      'Your booking changed meanwhile. Refresh to see the current state.',
    'already_active' => 'You already have a booking for this event.',
    'invalid_guest_count' => 'This number of seats is not allowed.',
    'event_unavailable' ||
    'occurrence_cancelled' => 'This event is not available for booking.',
    _ => 'The booking was not accepted.',
  };
}
