import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/time/iana_time_zone.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';

void main() {
  test(
    'preserves zone identity; known-zone validation belongs to the adapter',
    () {
      final zone = IanaTimeZone.parse('Europe/Riga');
      expect(zone.toString(), 'Europe/Riga');
      expect(zone.hashCode, IanaTimeZone.parse('Europe/Riga').hashCode);
      expect(zone, isNot(IanaTimeZone.parse('europe/riga')));
      final repository = TimezoneRepositoryImpl();
      expect(repository.isValidTimezone(zone.value), isTrue);
      final unknown = IanaTimeZone.parse('Unknown/Nowhere');
      expect(repository.isValidTimezone(unknown.value), isFalse);
      expect(IanaTimeZone.parse('Etc/GMT+3').value, 'Etc/GMT+3');
      expect(IanaTimeZone.parse('UTC').value, 'UTC');
    },
  );

  test('rejects empty, offset-only and malformed identifiers', () {
    for (final value in [
      '',
      '+03:00',
      '/Europe/Riga',
      'Europe//Riga',
      'Europe/Riga/',
      'Europe/../Riga',
      'Europe/Riga ',
      ' Europe/Riga',
      'UTC\n',
    ]) {
      expect(() => IanaTimeZone.parse(value), throwsFormatException);
    }
  });
}
