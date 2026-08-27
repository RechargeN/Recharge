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
      'booking_query.schema.json',
      'booking_read.schema.json',
      'booking_page.schema.json',
      'booking_availability.schema.json',
    ];

    test('all ten roots use Draft 2020-12 and the bounded vocabulary', () {
      final validator = BookingSchemaFixtureValidator();
      for (final fileName in rootSchemas) {
        final schema = readJsonObject('$bookingSchemaRoot/$fileName');
        expect(
          validator.validateSchemaDocument(schema),
          isEmpty,
          reason: fileName,
        );
        expect(schema[r'$id'], contains('/booking/v1/'));
        if ({
          'booking_command.schema.json',
          'booking_query.schema.json',
          'booking_read.schema.json',
          'booking_page.schema.json',
          'booking_availability.schema.json',
        }.contains(fileName)) {
          expect(schema['oneOf'], isA<List<Object?>>());
        } else {
          expect(
            (schema['properties'] as Map).containsKey('schemaVersion'),
            isTrue,
          );
        }
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
      }),
    );
  });

  test('safe revisions reject values above the cross-language maximum', () {
    expect(
      requireNonNegativeInt(bookingMaxSafeInteger, 'revision'),
      bookingMaxSafeInteger,
    );
    expect(
      () => requireNonNegativeInt(bookingMaxSafeInteger + 1, 'revision'),
      throwsFormatException,
    );
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

  test(
    'command is immutable and rejects actor authority or unknown fields',
    () {
      final mutablePayload = <String, Object?>{'bookingId': 'booking-1'};
      final command = BookingCommandDto(
        schemaVersion: 1,
        commandType: BookingCommandType.cancelBooking,
        requestId: 'request-1',
        idempotencyKey: 'idempotency-1',
        expectedBookingRevision: 0,
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
    },
  );

  test('command schema freezes all nine variants and revision ownership', () {
    final schema = readJsonObject(
      '$bookingSchemaRoot/booking_command.schema.json',
    );
    final variants = (schema['oneOf']! as List)
        .map((value) => (value as Map).cast<String, Object?>())
        .toList(growable: false);
    expect(variants, hasLength(BookingCommandType.values.length));

    final requiresExpectedRevision = <String>{
      'cancelBooking',
      'approveApplication',
      'rejectApplication',
      'leaveWaitlist',
      'acceptWaitlistHold',
      'declineWaitlistHold',
      'reconfirmBooking',
    };
    final seen = <String>{};
    for (final variant in variants) {
      final properties = (variant['properties']! as Map)
          .cast<String, Object?>();
      final commandType =
          ((properties['commandType']! as Map)['const']! as String);
      final required = (variant['required']! as List).cast<String>().toSet();
      expect(seen.add(commandType), isTrue);
      expect(
        required.contains('expectedBookingRevision'),
        requiresExpectedRevision.contains(commandType),
        reason: commandType,
      );
      expect(
        properties.containsKey('expectedBookingRevision'),
        requiresExpectedRevision.contains(commandType),
        reason: commandType,
      );
      expect(variant['additionalProperties'], isFalse);
    }
    expect(seen, BookingCommandType.values.map((value) => value.name).toSet());
  });

  test('D12 request IDs preserve exact opaque Unicode identity', () {
    BookingCommandDto command(String requestId) => BookingCommandDto(
      schemaVersion: 1,
      commandType: BookingCommandType.createBooking,
      requestId: requestId,
      idempotencyKey: 'stable-test-key',
      payload: const {'occurrenceId': 'occurrence-1', 'participantUnits': 1},
    );

    expect(command(' Request-A ').requestId, ' Request-A ');
    expect(
      command('Request-A').requestId,
      isNot(command('request-a').requestId),
    );
    expect(command('é').requestId, isNot(command('e\u0301').requestId));
    expect(
      command(List<String>.filled(128, '😀').join()).requestId.runes.length,
      128,
    );

    final d12BlankSet = String.fromCharCodes(<int>[
      ...List<int>.generate(5, (index) => 0x0009 + index),
      0x0020,
      0x0085,
      0x00A0,
      0x1680,
      ...List<int>.generate(11, (index) => 0x2000 + index),
      0x2028,
      0x2029,
      0x202F,
      0x205F,
      0x3000,
    ]);
    expect(() => command(d12BlankSet), throwsFormatException);
    expect(
      () => command(List<String>.filled(129, 'a').join()),
      throwsFormatException,
    );
    expect(() => command(String.fromCharCode(0xD800)), throwsFormatException);
  });

  test('bounded validator rejects unsupported normative keywords', () {
    final schema = readJsonObject(
      '$bookingSchemaRoot/booking_command.schema.json',
    );
    final mutated = <String, Object?>{...schema, r'$dynamicRef': '#'};
    expect(
      BookingSchemaFixtureValidator().validateSchemaDocument(mutated),
      contains(contains(r'uses unapproved keyword $dynamicRef')),
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
