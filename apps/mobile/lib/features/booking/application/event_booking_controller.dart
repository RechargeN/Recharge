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
  });

  final EventBookingPhase phase;

  /// The user's active Booking for this occurrence, as last confirmed by the
  /// server.
  final EventBookingView? booking;
  final bool hasPendingOperation;
  final String? message;

  bool get canBook =>
      phase == EventBookingPhase.ready &&
      (booking == null || !booking!.isActive) &&
      !hasPendingOperation;
  bool get canCancel =>
      phase == EventBookingPhase.ready &&
      booking != null &&
      booking!.isActive &&
      !hasPendingOperation;
  bool get canRetry =>
      phase == EventBookingPhase.unknownOutcome ||
      phase == EventBookingPhase.offline ||
      phase == EventBookingPhase.error;
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
    Uuid uuid = const Uuid(),
  }) : _gateway = gateway,
       _store = store,
       _uuid = uuid;

  final EventBookingGateway _gateway;
  final EventBookingOperationStore _store;
  final Uuid _uuid;
  final String occurrenceId;

  /// Server-generated pool and channel from Booking terms; both absent for
  /// unlimited capacity.
  final String? inventoryPoolId;
  final String? channel;
  final int eventRevision;

  EventBookingViewState _state = const EventBookingViewState(
    phase: EventBookingPhase.loading,
  );
  bool _busy = false;
  bool _disposed = false;

  EventBookingViewState get state => _state;

  void _emit(EventBookingViewState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Opens the screen: replays a journaled intent first (restart recovery),
  /// otherwise reads the server state.
  Future<void> load() async {
    if (_busy) return;
    _busy = true;
    try {
      _emit(
        EventBookingViewState(
          phase: EventBookingPhase.loading,
          booking: _state.booking,
        ),
      );
      final pending = await _store.read(occurrenceId);
      if (pending != null) {
        await _run(pending);
      } else {
        await _refresh();
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> book({int participantUnits = 1}) async {
    // Re-entrancy guard: a double tap is one intent, not two commands.
    if (_busy || !_state.canBook) return;
    _busy = true;
    try {
      var operation = await _store.read(occurrenceId);
      operation ??= EventBookingOperation(
        kind: EventBookingOperationKind.create,
        idempotencyKey: _uuid.v4(),
        occurrenceId: occurrenceId,
        inventoryPoolId: inventoryPoolId,
        channel: channel,
        participantUnits: participantUnits,
        eventRevision: eventRevision,
      );
      // The intent is durable before the first dispatch.
      await _store.write(operation);
      await _run(operation);
    } finally {
      _busy = false;
    }
  }

  Future<void> cancel() async {
    final booking = _state.booking;
    if (_busy || !_state.canCancel || booking == null) return;
    _busy = true;
    try {
      final operation = EventBookingOperation(
        kind: EventBookingOperationKind.cancel,
        idempotencyKey: _uuid.v4(),
        occurrenceId: occurrenceId,
        bookingId: booking.id,
        expectedBookingRevision: booking.revision,
      );
      await _store.write(operation);
      await _run(operation);
    } finally {
      _busy = false;
    }
  }

  /// Replays the journaled intent with its original idempotency key, or
  /// re-reads the server when nothing is pending.
  Future<void> retry() async {
    if (_busy) return;
    _busy = true;
    try {
      final pending = await _store.read(occurrenceId);
      if (pending != null) {
        await _run(pending);
      } else {
        await _refresh();
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _refresh() async {
    final result = await _gateway.activeFor(occurrenceId);
    switch (result.outcome) {
      case EventBookingOutcome.succeeded:
        _emit(
          EventBookingViewState(
            phase: EventBookingPhase.ready,
            booking: result.booking,
          ),
        );
      case EventBookingOutcome.offline:
      case EventBookingOutcome.unknownOutcome:
        _emit(
          EventBookingViewState(
            phase: EventBookingPhase.offline,
            booking: _state.booking,
            message: 'No connection. Try again when you are back online.',
          ),
        );
      case EventBookingOutcome.unauthenticated:
        _emit(
          const EventBookingViewState(
            phase: EventBookingPhase.error,
            message: 'Your session could not be confirmed. Try again.',
          ),
        );
      case EventBookingOutcome.rejected:
        _emit(
          const EventBookingViewState(
            phase: EventBookingPhase.error,
            message: 'Booking could not be loaded.',
          ),
        );
    }
  }

  Future<void> _run(EventBookingOperation operation) async {
    _emit(
      EventBookingViewState(
        phase: EventBookingPhase.submitting,
        booking: _state.booking,
        hasPendingOperation: true,
      ),
    );
    final result = await _gateway.execute(operation);
    switch (result.outcome) {
      case EventBookingOutcome.succeeded:
        await _store.clear(occurrenceId);
        // The server answer for create/cancel is only a confirmation; the
        // visible Booking is always re-read from the server.
        await _refresh();
      case EventBookingOutcome.unknownOutcome:
        _emit(
          EventBookingViewState(
            phase: EventBookingPhase.unknownOutcome,
            booking: _state.booking,
            hasPendingOperation: true,
            message:
                'We could not confirm the result. Checking again will not '
                'create a second booking.',
          ),
        );
      case EventBookingOutcome.offline:
        _emit(
          EventBookingViewState(
            phase: EventBookingPhase.offline,
            booking: _state.booking,
            hasPendingOperation: true,
            message:
                'No connection. Your request is saved and will not be '
                'duplicated.',
          ),
        );
      case EventBookingOutcome.unauthenticated:
        _emit(
          EventBookingViewState(
            phase: EventBookingPhase.error,
            booking: _state.booking,
            hasPendingOperation: true,
            message: 'Your session could not be confirmed. Try again.',
          ),
        );
      case EventBookingOutcome.rejected:
        // A final server refusal ends the intent; the user may start over.
        await _store.clear(occurrenceId);
        _emit(
          EventBookingViewState(
            phase: EventBookingPhase.error,
            booking: _state.booking,
            message: 'The booking was not accepted.',
          ),
        );
    }
  }
}
