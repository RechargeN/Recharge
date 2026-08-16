import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/currency_metadata.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('currency codes normalize and reject invalid structures', () {
    expect(CurrencyCode.parse(' eur '), CurrencyCode.eur);
    expect(CurrencyCode.tryParse('EU'), isNull);
    expect(CurrencyCode.tryParse('12A'), isNull);
  });

  test('metadata preserves currency-specific minor unit exponents', () {
    expect(CurrencyMetadata.tryFor(CurrencyCode.eur)?.minorUnitExponent, 2);
    expect(CurrencyMetadata.tryFor(CurrencyCode.jpy)?.minorUnitExponent, 0);
    expect(CurrencyMetadata.tryFor(CurrencyCode.bhd)?.minorUnitExponent, 3);
  });

  test('money arithmetic is exact and rejects mixed currencies', () {
    const Money first = Money(minorUnits: 10, currency: CurrencyCode.eur);
    const Money second = Money(minorUnits: 20, currency: CurrencyCode.eur);

    expect(
      first + second,
      const Money(minorUnits: 30, currency: CurrencyCode.eur),
    );
    expect(second - first, first);
    expect(
      () => first + const Money(minorUnits: 1, currency: CurrencyCode.usd),
      throwsA(isA<MoneyCurrencyMismatchException>()),
    );
  });

  test('money rejects values outside the JSON-safe integer range', () {
    final Money invalid = Money(
      minorUnits: Money.maxSafeMinorUnits + 1,
      currency: CurrencyCode.eur,
    );

    expect(() => invalid.minorUnits, throwsA(isA<MoneyRangeException>()));
    expect(() => invalid + const Money.zero(CurrencyCode.eur),
        throwsA(isA<MoneyRangeException>()));
  });
}
