import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/currency_metadata.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('currency normalization is structural and metadata is explicit', () {
    expect(CurrencyCode.parse(' eur '), CurrencyCode.eur);
    expect(CurrencyCode.parse('eur').hashCode, CurrencyCode.eur.hashCode);
    for (final source in ['', 'EU', 'EURO', 'E1R', '€UR']) {
      expect(() => CurrencyCode.parse(source), throwsFormatException);
    }
    expect(
      CurrencyMetadataRegistry.eurOnly.lookup(CurrencyCode.parse('USD')),
      isNull,
    );
    expect(
      () => CurrencyMetadata(code: CurrencyCode.eur, exponent: -1),
      throwsRangeError,
    );
    expect(
      () => CurrencyMetadata(code: CurrencyCode.eur, exponent: 7),
      throwsRangeError,
    );
    expect(
      () => CurrencyMetadataRegistry([
        CurrencyMetadata(code: CurrencyCode.eur, exponent: 2),
        CurrencyMetadata(code: CurrencyCode.eur, exponent: 3),
      ]),
      throwsArgumentError,
    );
  });
  test('integer arithmetic, equality and negative deltas', () {
    final a = Money(minorUnits: 101, currency: CurrencyCode.eur);
    final b = Money(minorUnits: 2, currency: CurrencyCode.eur);
    expect((a + b).minorUnits, 103);
    expect((b - a).minorUnits, -99);
    expect(a.scaledBy(3).minorUnits, 303);
    expect(a, Money(minorUnits: 101, currency: CurrencyCode.eur));
    expect(
      a.hashCode,
      Money(minorUnits: 101, currency: CurrencyCode.eur).hashCode,
    );
    expect(a.compareTo(b), greaterThan(0));
  });
  test('every arithmetic operation rejects currency mismatch', () {
    final eur = Money(minorUnits: 100, currency: CurrencyCode.eur);
    final usd = Money(minorUnits: 100, currency: CurrencyCode.parse('USD'));
    final mismatch = throwsA(
      isA<MoneyArithmeticException>().having(
        (e) => e.code,
        'code',
        MoneyArithmeticError.currencyMismatch,
      ),
    );
    expect(() => eur + usd, mismatch);
    expect(() => eur - usd, mismatch);
    expect(() => eur.compareTo(usd), mismatch);
    expect(eur, isNot(usd));
  });
  test('safe JSON bounds and intermediate arithmetic never wrap or round', () {
    Money m(int value) => Money(minorUnits: value, currency: CurrencyCode.eur);
    const max = Money.maxSafeMinorUnits;
    final overflow = throwsA(
      isA<MoneyArithmeticException>().having(
        (e) => e.code,
        'code',
        MoneyArithmeticError.outOfRange,
      ),
    );
    expect(m(max).minorUnits, max);
    expect(m(-max).minorUnits, -max);
    expect(() => m(max + 1), overflow);
    expect(() => m(-max - 1), overflow);
    expect(() => m(max) + m(1), overflow);
    expect(() => m(-max) - m(1), overflow);
    expect(() => m(max).scaledBy(2), overflow);
  });
}
