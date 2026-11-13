import 'package:api_contracts/api_contracts.dart';
import 'package:test/test.dart';

import 'support/booking_schema_fixture_validator.dart';

void main() {
  final valid = readJsonObject('$bookingSchemaRoot/fixtures/query_valid.json');
  final invalid = readJsonObject(
    '$bookingSchemaRoot/fixtures/query_invalid.json',
  );

  Map<String, Object?> availabilityOf(Map<String, Object?> answer) =>
      (answer['availability']! as Map).cast<String, Object?>();

  test(
    'every succeeded availability fixture parses; terms are read exactly',
    () {
      final parsed = <String, BookingAvailabilityDto>{
        for (final answer in readObjectList(valid, 'availability'))
          if (answer['kind'] == 'succeeded')
            answer['requestId']! as String: BookingAvailabilityDto.fromJson(
              availabilityOf(answer),
            ),
      };
      final finite = parsed['terms-finite']!.terms!;
      expect(finite.inventoryPoolId, 'pool_0123456789abcdef0123456789abcdef');
      expect(finite.channel, BookingChannel.onsite);
      expect(finite.partyMode, BookingPartyMode.partyWithoutNames);
      expect(finite.maxParticipantUnits, 3);
      expect(finite.cancellationDeadline, DateTime.utc(2026, 8, 27, 13));
      final unlimited = parsed['terms-unlimited']!.terms!;
      expect(unlimited.inventoryPoolId, isNull);
      expect(unlimited.channel, isNull);
      expect(unlimited.partyMode, BookingPartyMode.selfOnly);
      expect(
        parsed['terms-not-open']!.status,
        BookingAvailabilityStatus.notOpen,
      );
      expect(parsed['finite']!.terms, isNull, reason: 'terms stay optional');
    },
  );

  test('terms that break the contract fail closed, never guessed', () {
    final cases = readObjectList(invalid, 'cases').where(
      (entry) =>
          entry['schema'] == 'booking_availability.schema.json' &&
          (entry['reason']! as String).contains('terms'),
    );
    expect(cases, hasLength(4));
    for (final entry in cases) {
      final answer = (entry['value']! as Map).cast<String, Object?>();
      expect(
        () => BookingAvailabilityDto.fromJson(availabilityOf(answer)),
        throwsA(isA<BookingContractFormatException>()),
        reason: entry['reason']! as String,
      );
    }
  });
}
