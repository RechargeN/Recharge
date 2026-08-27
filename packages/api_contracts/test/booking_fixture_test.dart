import 'package:api_contracts/api_contracts.dart';
import 'package:test/test.dart';

import 'support/booking_schema_fixture_validator.dart';

void main() {
  final valid = readJsonObject('$bookingSchemaRoot/fixtures/valid.json');
  final invalid = readJsonObject('$bookingSchemaRoot/fixtures/invalid.json');
  final forward = readJsonObject('$bookingSchemaRoot/fixtures/forward.json');
  final schemaValidator = BookingSchemaFixtureValidator();

  test('valid shared fixtures round-trip without semantic loss', () {
    for (final raw in readObjectList(valid, 'bookings')) {
      expect(BookingDto.fromJson(raw).toJson(), equals(raw));
    }
    for (final raw in readObjectList(valid, 'holds')) {
      expect(BookingHoldDto.fromJson(raw).toJson(), equals(raw));
    }
    for (final raw in readObjectList(valid, 'policies')) {
      expect(BookingPolicyDto.fromJson(raw).toJson(), equals(raw));
    }
    for (final raw in readObjectList(valid, 'commands')) {
      expect(
        schemaValidator.validateInstance('booking_command.schema.json', raw),
        isEmpty,
        reason: '${raw['commandType']} ${raw['requestId']}',
      );
      expect(BookingCommandDto.fromJson(raw).toJson(), equals(raw));
    }
    for (final raw in readObjectList(valid, 'errors')) {
      expect(BookingErrorDto.fromJson(raw).toJson(), equals(raw));
    }
    for (final raw in readObjectList(valid, 'results')) {
      expect(BookingResultDto.fromJson(raw).toJson(), equals(raw));
    }
  });

  test('every invalid fixture fails with a typed format error', () {
    for (final fixture in readObjectList(invalid, 'cases')) {
      final target = fixture['target']! as String;
      final value = (fixture['value']! as Map).cast<String, Object?>();
      Object Function() decode = switch (target) {
        'booking' => () => BookingDto.fromJson(value),
        'hold' => () => BookingHoldDto.fromJson(value),
        'policy' => () => BookingPolicyDto.fromJson(value),
        'command' => () => BookingCommandDto.fromJson(value),
        'error' => () => BookingErrorDto.fromJson(value),
        _ => throw StateError('Unknown fixture target $target'),
      };
      expect(
        decode,
        throwsFormatException,
        reason: fixture['reason'] as String,
      );
      if (target == 'command') {
        expect(
          schemaValidator.validateInstance(
            'booking_command.schema.json',
            value,
          ),
          isNotEmpty,
          reason: fixture['reason'] as String,
        );
      }
    }
  });

  test('valid command fixtures cover every closed command variant', () {
    final commandTypes = readObjectList(
      valid,
      'commands',
    ).map((command) => command['commandType']).toSet();
    expect(
      commandTypes,
      BookingCommandType.values.map((value) => value.name).toSet(),
    );
  });

  test('forward fixtures become opaque unsupported results', () {
    for (final fixture in readObjectList(forward, 'cases')) {
      final value = (fixture['value']! as Map).cast<String, Object?>();
      final result = BookingResultDto.fromJsonFailClosed(value);
      expect(
        result.kind,
        BookingResultKind.unsupportedContract,
        reason: fixture['reason'] as String,
      );
      expect(result.booking, isNull);
      expect(result.error, isNull);
      expect(result.unsupportedPayload, equals(value));
    }
  });
}
