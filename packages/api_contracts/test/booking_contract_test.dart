import 'package:api_contracts/api_contracts.dart';
import 'package:test/test.dart';

import 'support/booking_schema_fixture_validator.dart';

void main() {
  group('Booking v1 schemas', () {
    const rootSchemas = <String>[
      'booking.schema.json',
      'booking_hold.schema.json',
      'booking_policy.schema.json',
      'booking_command.schema.json',
      'booking_result.schema.json',
      'booking_error.schema.json',
    ];

    test('all six roots use Draft 2020-12 and the bounded vocabulary', () {
      final validator = BookingSchemaFixtureValidator();
      for (final fileName in rootSchemas) {
        final schema = readJsonObject('$bookingSchemaRoot/$fileName');
        expect(
          validator.validateSchemaDocument(schema),
          isEmpty,
          reason: fileName,
        );
        expect(schema[r'$id'], contains('/booking/v1/'));
        expect(
          (schema['properties'] as Map).containsKey('schemaVersion'),
          isTrue,
        );
      }
    });

    test('common schema also uses only the approved vocabulary', () {
      final common = readJsonObject('$bookingSchemaRoot/common.schema.json');
      expect(
        BookingSchemaFixtureValidator().validateSchemaDocument(common),
        isEmpty,
      );
    });
  });

  test('closed wire dictionaries expose only canonical v1 values', () {
    expect(BookingState.values.map((value) => value.name), [
      'pending',
      'confirmed',
      'cancelled',
      'expired',
      'waitlisted',
    ]);
    expect(BookingCommandType.values, hasLength(9));
    expect(BookingHoldState.values, hasLength(5));
    expect(
        BookingErrorCode.values.map((value) => value.wireValue),
        containsAll(<String>{
          'sold_out',
          'concurrency_cap_reached',
          'revision_conflict',
          'idempotency_conflict',
          'unsupported_schema',
        }));
  });

  test('policy v1 is exact and cannot be silently broadened', () {
    final policy = BookingPolicyDto.fromJson({
      'schemaVersion': 1,
      'policyVersion': 1,
      'maxConcurrentFiniteAllocations': 5,
      'countingRule': 'onePerBookingOrActiveHold',
      'unlimitedBookingCounts': false,
    });
    expect(policy.maxConcurrentFiniteAllocations, 5);
    expect(policy.unlimitedBookingCounts, isFalse);
    expect(
      () => BookingPolicyDto.fromJson({
        ...policy.toJson(),
        'maxConcurrentFiniteAllocations': 6,
      }),
      throwsFormatException,
    );
  });

  test('command is immutable and rejects actor authority or unknown fields',
      () {
    final mutablePayload = <String, Object?>{
      'bookingId': 'booking-1',
    };
    final command = BookingCommandDto(
      schemaVersion: 1,
      commandType: BookingCommandType.cancelBooking,
      requestId: 'request-1',
      idempotencyKey: 'idempotency-1',
      payload: mutablePayload,
    );
    mutablePayload['bookingId'] = 'changed';
    expect(command.payload['bookingId'], 'booking-1');
    expect(() => command.payload['x'] = true, throwsUnsupportedError);

    expect(
      () => BookingCommandDto.fromJson({
        ...command.toJson(),
        'payload': {'bookingId': 'booking-1', 'actorId': 'admin-1'},
      }),
      throwsFormatException,
    );
    expect(
      () => BookingCommandDto.fromJson({
        ...command.toJson(),
        'unexpected': true,
      }),
      throwsFormatException,
    );
  });

  test('error details are scalar, allowlisted and privacy safe', () {
    final error = BookingErrorDto(
      schemaVersion: 1,
      code: BookingErrorCode.concurrencyCapReached,
      retryable: false,
      correlationId: 'correlation-1',
      details: const {'limit': 5, 'policyVersion': 1},
    );
    expect(error.toJson()['code'], 'concurrency_cap_reached');
    expect(
      () => BookingErrorDto(
        schemaVersion: 1,
        code: BookingErrorCode.forbidden,
        retryable: false,
        correlationId: 'correlation-2',
        details: const {'email': 'private@example.invalid'},
      ),
      throwsFormatException,
    );
  });
}
