import 'package:test/test.dart';

import 'support/booking_schema_fixture_validator.dart';

void main() {
  final validator = BookingSchemaFixtureValidator();
  final valid = readJsonObject('$bookingSchemaRoot/fixtures/query_valid.json');
  final invalid = readJsonObject(
    '$bookingSchemaRoot/fixtures/query_invalid.json',
  );
  final forward = readJsonObject(
    '$bookingSchemaRoot/fixtures/query_forward.json',
  );

  const validGroups = <String, String>{
    'queries': 'booking_query.schema.json',
    'reads': 'booking_read.schema.json',
    'pages': 'booking_page.schema.json',
    'availability': 'booking_availability.schema.json',
  };

  test('all shared query and response fixtures validate', () {
    for (final entry in validGroups.entries) {
      for (final value in readObjectList(valid, entry.key)) {
        expect(
          validator.validateInstance(entry.value, value),
          isEmpty,
          reason: '${entry.key}: ${value['requestId']}',
        );
      }
    }
  });

  test('all invalid query and response fixtures fail closed', () {
    for (final fixture in readObjectList(invalid, 'cases')) {
      final schema = fixture['schema']! as String;
      final value = (fixture['value']! as Map).cast<String, Object?>();
      expect(
        validator.validateInstance(schema, value),
        isNotEmpty,
        reason: fixture['reason']! as String,
      );
    }
  });

  test('all forward query fixtures fail closed', () {
    for (final fixture in readObjectList(forward, 'cases')) {
      final schema = fixture['schema']! as String;
      final value = (fixture['value']! as Map).cast<String, Object?>();
      expect(
        validator.validateInstance(schema, value),
        isNotEmpty,
        reason: fixture['reason']! as String,
      );
    }
  });

  test('opaque unsupported payloads enforce byte and depth bounds', () {
    expect(validator.validateBoundedOpaquePayload({'future': 'safe'}), isEmpty);
    expect(
      validator.validateBoundedOpaquePayload({
        for (var index = 0; index < 9; index++)
          'field$index': List<String>.filled(512, 'x').join(),
      }),
      contains(contains('4096')),
    );
    Object? tooDeep = 'leaf';
    for (var index = 0; index < 9; index++) {
      tooDeep = {'nested': tooDeep};
    }
    expect(
      validator.validateBoundedOpaquePayload(tooDeep),
      contains(contains('depth 8')),
    );
  });

  test('cursor maximum is enforced at 2048 printable ASCII characters', () {
    final value = <String, Object?>{
      'schemaVersion': 1,
      'queryType': 'listMyBookings',
      'requestId': 'cursor-max',
      'payload': {'cursor': List<String>.filled(2049, 'x').join()},
    };
    expect(
      validator.validateInstance('booking_query.schema.json', value),
      isNotEmpty,
    );
  });
}
