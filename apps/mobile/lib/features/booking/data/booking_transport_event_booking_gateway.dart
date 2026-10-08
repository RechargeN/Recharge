import 'package:api_contracts/api_contracts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/backend_contract.dart';
import '../../../core/network/backend_transport.dart';
import '../domain/repositories/event_booking_gateway.dart';
import 'booking_callable_adapter.dart';
import 'booking_command_gate.dart';

/// Event Booking gateway over the existing Booking transport. It adds no Auth
/// or Session logic: Session repair stays inside the Functions port, and the
/// operation journal and receipts stay inside [BookingCallableAdapter].
final class BookingTransportEventBookingGateway implements EventBookingGateway {
  BookingTransportEventBookingGateway({
    required BookingCallableAdapter adapter,
    required BookingCallablePort port,
    required BookingCommandGate gate,
    Uuid uuid = const Uuid(),
  }) : _adapter = adapter,
       _port = port,
       _gate = gate,
       _uuid = uuid;

  final BookingCallableAdapter _adapter;
  final BookingCallablePort _port;
  final BookingCommandGate _gate;
  final Uuid _uuid;

  @override
  Future<EventBookingResult> activeFor(String occurrenceId) async {
    _gate.assertAllowed();
    final Map<String, Object?> raw;
    try {
      raw = await _port.invoke('listMyBookingsV1', <String, Object?>{
        'schemaVersion': 1,
        'queryType': 'listMyBookings',
        'requestId': _uuid.v4(),
        'payload': <String, Object?>{'pageSize': 50},
      });
    } on BookingCallableFailure catch (error) {
      return EventBookingResult(_outcomeForFailure(error));
    }
    if (raw['kind'] != 'succeeded') {
      final error = raw['error'];
      final code = error is Map ? error['code'] : null;
      return EventBookingResult(
        code == 'session_revoked' ||
                code == 'session_expired' ||
                code == 'unauthenticated'
            ? EventBookingOutcome.unauthenticated
            : EventBookingOutcome.rejected,
      );
    }
    final page = raw['page'];
    final items = page is Map ? page['items'] : null;
    if (items is! List) {
      return const EventBookingResult(EventBookingOutcome.rejected);
    }
    for (final item in items) {
      if (item is! Map) continue;
      final BookingDto dto;
      try {
        dto = BookingDto.fromJson(Map<String, Object?>.from(item));
      } on Object {
        continue;
      }
      final view = _view(dto);
      if (view.occurrenceId == occurrenceId && view.isActive) {
        return EventBookingResult(EventBookingOutcome.succeeded, booking: view);
      }
    }
    return const EventBookingResult(EventBookingOutcome.succeeded);
  }

  @override
  Future<EventBookingTermsResult> termsFor({
    required String eventId,
    required String occurrenceId,
    String? channel,
  }) async {
    _gate.assertAllowed();
    final Map<String, Object?> raw;
    try {
      raw = await _port.invoke('getEventAvailabilityV1', <String, Object?>{
        'schemaVersion': 1,
        'queryType': 'getEventAvailability',
        'requestId': _uuid.v4(),
        'payload': <String, Object?>{
          'eventId': eventId,
          'occurrenceId': occurrenceId,
          if (channel != null) 'channel': channel,
        },
      });
    } on BookingCallableFailure catch (error) {
      return EventBookingTermsResult(switch (_outcomeForFailure(error)) {
        EventBookingOutcome.unauthenticated =>
          EventBookingTermsOutcome.unauthenticated,
        EventBookingOutcome.unknownOutcome =>
          EventBookingTermsOutcome.unknownOutcome,
        _ => EventBookingTermsOutcome.offline,
      });
    }
    if (raw['kind'] != 'succeeded') {
      final error = raw['error'];
      final Object? code = error is Map ? error['code'] : null;
      return EventBookingTermsResult(
        code == 'session_revoked' ||
                code == 'session_expired' ||
                code == 'unauthenticated'
            ? EventBookingTermsOutcome.unauthenticated
            : EventBookingTermsOutcome.unavailable,
        code: code is String ? code : null,
      );
    }
    final BookingAvailabilityDto availability;
    try {
      availability = BookingAvailabilityDto.fromJson(
        Map<String, Object?>.from(raw['availability']! as Map),
      );
    } on Object {
      return const EventBookingTermsResult(
        EventBookingTermsOutcome.unavailable,
        code: 'contract_invalid',
      );
    }
    final BookingAvailabilityTermsDto? terms = availability.terms;
    if (terms == null) {
      return const EventBookingTermsResult(
        EventBookingTermsOutcome.unavailable,
        code: 'terms_unavailable',
      );
    }
    return EventBookingTermsResult(
      EventBookingTermsOutcome.succeeded,
      terms: EventBookingTerms(
        eventId: availability.eventId,
        occurrenceId: availability.occurrenceId,
        eventRevision: availability.eventRevision,
        status: availability.status.name,
        maxParticipantUnits: terms.maxParticipantUnits,
        inventoryPoolId: terms.inventoryPoolId,
        channel: terms.channel?.name,
        cancellationDeadline: terms.cancellationDeadline,
      ),
    );
  }

  @override
  Future<EventBookingResult> execute(EventBookingOperation operation) async {
    _gate.assertAllowed();
    final BookingCommandDto command;
    BookingReconciliationRequest? reconciliation;
    final String callable;
    switch (operation.kind) {
      case EventBookingOperationKind.create:
        callable = 'createInternalBookingV1';
        command = BookingCommandDto(
          schemaVersion: bookingContractSchemaVersion,
          commandType: BookingCommandType.createBooking,
          requestId: _uuid.v4(),
          idempotencyKey: operation.idempotencyKey,
          occurredAgainstEventRevision: operation.eventRevision,
          payload: <String, Object?>{
            'occurrenceId': operation.occurrenceId,
            // Unlimited capacity has neither pool nor channel (Booking needs
            // them together); absent, never null.
            if (operation.inventoryPoolId != null)
              'inventoryPoolId': operation.inventoryPoolId,
            if (operation.channel != null) 'channel': operation.channel,
            'participantUnits': operation.participantUnits,
            'namedGuests': <Object?>[],
          },
        );
      case EventBookingOperationKind.cancel:
        callable = 'cancelInternalBookingV1';
        command = BookingCommandDto(
          schemaVersion: bookingContractSchemaVersion,
          commandType: BookingCommandType.cancelBooking,
          requestId: _uuid.v4(),
          idempotencyKey: operation.idempotencyKey,
          expectedBookingRevision: operation.expectedBookingRevision,
          payload: <String, Object?>{
            'bookingId': operation.bookingId,
            'reasonCode': 'user_cancelled',
          },
        );
        reconciliation = BookingReconciliationRequest(
          callableName: 'getMyBookingV1',
          query: <String, Object?>{
            'schemaVersion': 1,
            'queryType': 'getMyBooking',
            'requestId': _uuid.v4(),
            'payload': <String, Object?>{'bookingId': operation.bookingId},
          },
        );
    }
    final BackendResult<BookingResultDto> result;
    try {
      result = await _adapter.execute(
        callable,
        command,
        cancellationToken: BackendCancellationToken(),
        reconciliation: reconciliation,
      );
    } on BookingCallableFailure catch (error) {
      return EventBookingResult(_outcomeForFailure(error));
    }
    return switch (result) {
      BackendSuccess<BookingResultDto>(:final value) => EventBookingResult(
        EventBookingOutcome.succeeded,
        booking: value.booking == null ? null : _view(value.booking!),
      ),
      BackendUnknownOutcome<BookingResultDto>() => const EventBookingResult(
        EventBookingOutcome.unknownOutcome,
      ),
      BackendCancelled<BookingResultDto>() => const EventBookingResult(
        EventBookingOutcome.unknownOutcome,
      ),
      BackendRejected<BookingResultDto>(:final failure) => EventBookingResult(
        switch (failure.code) {
          BackendFailureCode.unavailable => EventBookingOutcome.offline,
          BackendFailureCode.unauthenticated =>
            EventBookingOutcome.unauthenticated,
          _ => EventBookingOutcome.rejected,
        },
      ),
    };
  }

  EventBookingOutcome _outcomeForFailure(BookingCallableFailure error) {
    if (error.code == 'unauthenticated') {
      return EventBookingOutcome.unauthenticated;
    }
    return error.dispatched
        ? EventBookingOutcome.unknownOutcome
        : EventBookingOutcome.offline;
  }

  EventBookingView _view(BookingDto dto) => EventBookingView(
    id: dto.id,
    occurrenceId: dto.occurrenceId,
    state: EventBookingState.values.byName(dto.state.name),
    participantUnits: dto.participantUnits,
    revision: dto.revision,
  );
}
