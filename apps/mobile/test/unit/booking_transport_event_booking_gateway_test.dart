import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_command_gate.dart';
import 'package:recharge/features/booking/data/booking_transport_event_booking_gateway.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';

const String _now = '2026-11-01T12:00:00.000Z';

Map<String, Object?> _booking({
  int revision = 3,
  String state = 'confirmed',
  String reconfirmationState = 'confirmed',
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'schemaVersion': 1,
  'id': '01JBOOKINGF2GATEWAY000001',
  'revision': revision,
  'userId': '01JUSERF2GATEWAY000000001',
  'marketId': 'LV',
  'eventId': '01JEVENTF2GATEWAY00000001',
  'occurrenceId': '01JOCCURRENCEF2GATEWAY001',
  'inventoryPoolId': 'pool_f2',
  'channel': 'onsite',
  'admissionMode': 'booking',
  'confirmationMode': 'instant',
  'state': state,
  'participantUnits': 2,
  'namedGuests': <Object?>[],
  'reconfirmationState': reconfirmationState,
  'createdAt': '2026-11-01T10:00:00.000Z',
  'updatedAt': _now,
  'confirmedAt': '2026-11-01T10:00:00.000Z',
  ...extra,
};

Map<String, Object?> _result(
  String kind, {
  Map<String, Object?>? booking,
  String? code,
  int? retryAfterSeconds,
}) => <String, Object?>{
  'schemaVersion': 1,
  'kind': kind,
  'requestId': 'request_f2',
  'correlationId': 'correlation_f2',
  'serverTime': _now,
  if (booking != null) 'booking': booking,
  if (code != null)
    'error': <String, Object?>{
      'schemaVersion': 1,
      'code': code,
      'retryable': kind == 'retryableFailure',
      'correlationId': 'correlation_f2',
      if (retryAfterSeconds != null)
        'details': <String, Object?>{'retryAfterSeconds': retryAfterSeconds},
    },
};

final class _Port implements BookingCallablePort {
  _Port(this.answer);

  Map<String, Object?> answer;
  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    calls.add((callableName, command));
    return answer;
  }
}

final class _Gate implements BookingCommandGate {
  @override
  bool get allowed => true;

  @override
  void assertAllowed() {}
}

BookingTransportEventBookingGateway _gateway(_Port port) =>
    BookingTransportEventBookingGateway(
      adapter: BookingCallableAdapter(
        port: port,
        operations: InMemoryBookingOperationStore(),
        clock: () => DateTime.parse(_now),
      ),
      port: port,
      gate: _Gate(),
    );

const EventBookingOperation _reconfirm = EventBookingOperation(
  kind: EventBookingOperationKind.reconfirm,
  idempotencyKey: 'idem_f2_gateway_reconfirm',
  occurrenceId: '01JOCCURRENCEF2GATEWAY001',
  bookingId: '01JBOOKINGF2GATEWAY000001',
  expectedBookingRevision: 2,
  materialRevision: 8,
);

void main() {
  test('reconfirm sends the exact Booking and material revisions', () async {
    final _Port port = _Port(
      _result(
        'succeeded',
        booking: _booking(
          extra: <String, Object?>{
            'reconfirmationRequiredForRevision': 8,
            'reconfirmationDeadlineUtc': '2026-11-02T17:00:00.000Z',
          },
        ),
      ),
    );
    final EventBookingResult result = await _gateway(port).execute(_reconfirm);
    expect(result.outcome, EventBookingOutcome.succeeded);
    final (String callable, Map<String, Object?> command) = port.calls.single;
    expect(callable, 'reconfirmInternalBookingV1');
    expect(command['commandType'], 'reconfirmBooking');
    expect(command['expectedBookingRevision'], 2);
    expect(command['payload'], <String, Object?>{
      'bookingId': '01JBOOKINGF2GATEWAY000001',
      'materialRevision': 8,
    });
    expect(
      result.booking?.reconfirmationState,
      EventReconfirmationState.confirmed,
    );
  });

  test('a typed refusal keeps the server reason', () async {
    for (final String code in <String>[
      'reconfirmation_deadline_passed',
      'material_revision_mismatch',
      'sold_out',
      'active_booking_limit_reached',
    ]) {
      final _Port port = _Port(_result('rejected', code: code));
      final EventBookingResult result = await _gateway(
        port,
      ).execute(_reconfirm);
      expect(result.outcome, EventBookingOutcome.rejected, reason: code);
      expect(result.refusalCode, code);
    }
  });

  test('too many attempts is not offline and carries its wait', () async {
    final _Port port = _Port(
      _result('retryableFailure', code: 'rate_limited', retryAfterSeconds: 42),
    );
    final EventBookingResult result = await _gateway(port).execute(_reconfirm);
    expect(result.outcome, EventBookingOutcome.rateLimited);
    expect(result.retryAfter, const Duration(seconds: 42));
  });

  test('a Booking read by id reports why it ended', () async {
    final _Port port = _Port(<String, Object?>{
      'schemaVersion': 1,
      'queryType': 'getMyBooking',
      'requestId': 'request_f2',
      'serverTime': _now,
      'kind': 'found',
      'booking': _booking(
        state: 'cancelled',
        reconfirmationState: 'missed',
        extra: <String, Object?>{
          'terminalReason': 'missedReconfirmation',
          'cancelledAt': _now,
        },
      ),
    });
    final EventBookingResult result = await _gateway(
      port,
    ).booking('01JBOOKINGF2GATEWAY000001');
    expect(port.calls.single.$1, 'getMyBookingV1');
    expect(result.booking?.state, EventBookingState.cancelled);
    expect(result.booking?.terminalReason, 'missedReconfirmation');
    expect(
      result.booking?.reconfirmationState,
      EventReconfirmationState.missed,
    );
    expect(result.booking?.reconfirmationRequiredForRevision, isNull);
  });
}
