import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('Money parses decimal input without binary floating-point storage', () {
    expect(
      Money.tryParseMajor('12.34', currencyCode: 'eur'),
      Money(minorUnits: 1234, currencyCode: 'EUR'),
    );
    expect(Money.tryParseMajor('12.345', currencyCode: 'EUR'), isNull);
  });

  test('Money persists integer minor units and explicit currency', () {
    final Money value = Money(minorUnits: 999, currencyCode: 'EUR');
    expect(value.toJson(), <String, Object>{
      'minorUnits': 999,
      'currencyCode': 'EUR',
    });
    expect(Money.fromJsonOrNull(value.toJson()), value);
  });

  test('legacy major-unit reader is isolated and fails closed', () {
    expect(
      Money.fromJsonOrNull(12.34, legacyCurrencyCode: 'EUR'),
      Money(minorUnits: 1234, currencyCode: 'EUR'),
    );
    expect(Money.fromJsonOrNull(double.nan, legacyCurrencyCode: 'EUR'), isNull);
    expect(
      () => Money(minorUnits: -1, currencyCode: 'EUR'),
      throwsAssertionError,
    );
  });

  test(
    'invalid persisted minor units fail closed and zero normalizes currency',
    () {
      expect(
        Money.fromJsonOrNull(<String, Object>{
          'minorUnits': -1,
          'currencyCode': 'EUR',
        }),
        isNull,
      );
      expect(Money.zero('eur').currencyCode, 'EUR');
    },
  );

  test('different currencies cannot be combined or compared', () {
    final Money eur = Money(minorUnits: 100, currencyCode: 'EUR');
    final Money usd = Money(minorUnits: 100, currencyCode: 'USD');
    expect(() => eur + usd, throwsStateError);
    expect(() => eur.compareTo(usd), throwsStateError);
  });
}
